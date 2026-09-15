# fcg-observabilidade-service

Stack de observabilidade do FCGames: **Prometheus** (scrape de métricas HTTP) +
**Grafana** (dashboard provisionado automaticamente).

## O que sobe

| Serviço | Porta | Acesso |
|---|---|---|
| Prometheus | 9090 | http://localhost:9090 |
| Grafana | 3000 | http://localhost:3000 (dashboard "FCGames Observability" já provisionado) |

`prometheus.yml` faz scrape de Users, Catalog, Payments e Notifications
(endpoint `/metrics`, exposto via `prometheus-net` em cada API/worker).

## Rodando localmente

```bash
docker compose -f docker-compose.yml.yml up -d
```

## Deploy (EC2, docker-compose)

`infra/` provisiona uma EC2 dedicada que sobe essa mesma stack (ver
`.github/workflows/deploy.yml`).

> **Pendências conhecidas:**
> - Essa entrega ainda é baseada em docker-compose numa EC2, não em manifests Kubernetes.
> - O arquivo principal ainda tem o Zabbix configurado (não faz parte do escopo da
>   Fase 3 — só Prometheus/Grafana são exigidos); vale remover pra não gastar recursos
>   da EC2 com um serviço que não vai ser demonstrado.
> - Nome do arquivo principal está com extensão duplicada (`docker-compose.yml.yml`).
