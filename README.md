# fcg-observabilidade-service

Prometheus + Grafana monitorando as APIs do FCGames, numa EC2 do free tier,
publicados por GitHub Actions.

## Como funciona

O Prometheus **coleta**: a cada 15s ele lê o endpoint `/metrics` de cada API e
guarda o resultado com a hora. O Grafana **só desenha**: consulta o Prometheus e
monta os painéis, sem armazenar métrica nenhuma.

```
APIs .NET  ──/metrics──>  Prometheus  ──consulta──>  Grafana  ──>  navegador
   :5001                    :9090                     :3000
   :5002

Zabbix (server :10051 + web :8080 + MariaDB) — monitoramento de infraestrutura
```

O pipeline em `.github/workflows/deploy.yml` faz, nesta ordem:

1. Autentica na AWS via OIDC (credencial temporária, sem chave guardada no GitHub)
2. `terraform apply` na pasta `infra/` — cria a EC2 e o security group
3. Espera a instância registrar no SSM
4. Envia `docker-compose.yml`, `prometheus.yml` e `grafana/` via SSM Run Command
5. Roda `docker compose up -d` dentro da EC2

O deploy não usa SSH: o SSM entrega os comandos pela própria API da AWS. A porta
22 continua aberta para acesso manual, mas o Session Manager também funciona e
dispensa chave.

## Serviços monitorados

| Job | Porta | Status |
| --- | --- | --- |
| `fcg-users-service` | 5001 | ativo |
| `fcg-catalog-service` | 5002 | ativo |
| `fcg-payments-service` | 5003 | comentado |
| `fcg-notifications-service` | 5004 | comentado |

Os quatro expõem `/metrics` via `prometheus-net`, mas só users e catalog estão no
escopo atual. Para ativar os outros, descomente os jobs em `prometheus.yml`.

O `fcg-notifications-service` é um worker de RabbitMQ sem controllers: ele sobe
como target `UP`, mas os painéis de latência e throughput mostram só o tráfego
dos próprios health checks.

## Como o Prometheus acha as APIs

Pela API da EC2, não por endereço fixo. O Auto Scaling Group de cada serviço
troca a instância — e o IP — a qualquer momento, então alvo estático quebraria no
primeiro replace.

O filtro casa por curinga na tag `Name` da instância — `*users*` e `*catalog*`.
As instâncias da conta se chamam `fcg-users-servi...`, `fcg-catalog-se...` e
`fcg-payments-...`, então o curinga pega todas sem depender do nome exato.

Se uma API não aparecer nos targets, confira essa tag na instância dela: é o
ponto de encontro entre os dois repositórios, e quando não bate o alvo fica
vazio sem gerar erro em lugar nenhum.

## Deploy

O pipeline roda sozinho em push para `main`. Para disparar à mão, use
**Actions → Plan e Deploy Stack de Monitoramento Grafana → Run workflow**.

Em pull request para `main` roda só o `plan`, sem aplicar nada.

### Segredo necessário

| Segredo | Para quê |
| --- | --- |
| `SSH_PUBLIC_KEY` | Chave pública do par `monitoring-key`, usada pelo Terraform |

A role `GitHubActions-Observabilidade-Deploy-Role` precisa poder criar EC2, IAM
(role e instance profile) e security group, além de chamar `ssm:SendCommand`.

> **Grafana sem senha configurada.** Ele sobe com `admin` / `admin`, por decisão
> do time. Como a porta 3000 fica aberta, quem souber o IP entra como admin. A
> proteção prática aqui é restringir `grafana_allowed_cidrs` em
> `infra/variables.tf` ao IP de vocês — mais eficaz que senha em HTTP puro, onde
> ela trafega em texto claro de qualquer forma. Para definir uma senha depois,
> crie `/opt/observability/.env` com `GRAFANA_ADMIN_PASSWORD=...` e rode
> `docker compose up -d`.

### Depois do deploy

O endereço sai no último passo do workflow, ou:

```bash
cd infra && terraform output -raw grafana_url
```

## Acesso

- **Grafana** — porta 3000, com login. O dashboard "FCGames — Observabilidade"
  já vem provisionado como home.
- **Zabbix** — porta 8080, login padrão `Admin` / `zabbix`. **Troque no primeiro
  acesso**: a porta está aberta na internet com a senha de fábrica.
- **Prometheus** — porta 9090, **sem autenticação nenhuma**. O padrão abre para
  `0.0.0.0/0`; ajuste `prometheus_allowed_cidrs` em `infra/variables.tf` para o
  seu IP, ou feche e use port forward do Session Manager.

Para abrir um shell na instância sem SSH:

```bash
aws ssm start-session --target <instance-id> --region sa-east-1
```

## Zabbix e o limite de memória

A stack tem cinco containers. Medindo com a stack no ar e ociosa:

| Container | RAM |
| --- | --- |
| grafana | 365 MB |
| zabbix-db (MariaDB) | 259 MB |
| zabbix-web | 49 MB |
| prometheus | 39 MB |
| zabbix-server | 35 MB |
| **total** | **~746 MB** |

A `t3.micro` tem 1 GB (é ela, não a `t2.micro`, que é elegível ao free tier em
sa-east-1). Somando o próprio Ubuntu (~300 MB), passa do limite — e é por isso
que o `user_data` configura 2 GB de swap. Funciona, mas swap é disco,
não memória: sob carga fica lento.

Se travar ou morrer, suba o tamanho da máquina:

```hcl
# infra/variables.tf
variable "instance_type" {
  default = "t3.small" # 2 GB — fora do free tier
}
```

O Prometheus e o Zabbix se sobrepõem: os dois coletam métricas. O Prometheus
cobre as APIs .NET (via `/metrics`), e o Zabbix é mais forte em infraestrutura —
CPU, disco e rede de servidores. Manter os dois é uma decisão do time, não uma
necessidade técnica.
