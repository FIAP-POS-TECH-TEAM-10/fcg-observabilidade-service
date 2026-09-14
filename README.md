# FCGames Observability - ECS/Fargate

Estrutura preparada para rodar Prometheus + Grafana no Amazon ECS/Fargate.

## Arquitetura

- `fcg-prometheus`: Prometheus em ECS/Fargate, porta 9090.
- `fcg-grafana`: Grafana em ECS/Fargate, porta 3000.
- `fcg-users-service`: serviço ECS das APIs, publicado via Service Connect como `fcg-users-service:5001`.
- `fcg-catalog-service`: serviço ECS das APIs, publicado via Service Connect como `fcg-catalog-service:5002`.
- Namespace Service Connect: `fcgames.local`.

O Service Connect cria os endpoints usados pelos clientes ECS e permite que tarefas no namespace usem nomes curtos. Os serviços servidores precisam ter um `name` no `portMapping` e uma configuração de Service Connect que aponte para esse nome de porta.

## 1. Pré-requisitos

- AWS CLI configurado.
- Docker.
- ECS Cluster em uma VPC.
- Subnets privadas com saída para a Internet por NAT Gateway, ou endpoints VPC adequados para ECR/CloudWatch/Secrets Manager.
- IAM role `ecsTaskExecutionRole` com as permissões padrão do AmazonECSTaskExecutionRolePolicy. A task definition usa `awslogs`, suportado pelo Fargate.
- Security Group permitindo tráfego entre Prometheus e as APIs nas portas 5001 e 5002, e Grafana na porta 3000 apenas a partir do ALB.

## 2. ECR

```bash
cd observability
export AWS_REGION=sa-east-1
./aws/create-ecr.sh
./aws/build-and-push.sh
```

## 3. Cluster e Service Connect

```bash
./aws/create-infra.sh
```

O script usa `fcgames.local` como namespace Service Connect. O namespace deve estar na mesma região do cluster/serviço.

## 4. Secret do Grafana

Crie o secret antes do service:

```bash
aws secretsmanager create-secret \
  --name fcgames/grafana \
  --secret-string 'SENHA_FORTE' \
  --region sa-east-1
```

A role de execução da task precisa conseguir ler esse secret.

## 5. Task definitions

```bash
./aws/register-task-definitions.sh
```

## 6. Service Connect das APIs

Nas Task Definitions existentes de `fcg-users-service` e `fcg-catalog-service`, o `portMappings` da porta HTTP precisa ter nome:

### Users

```json
{
  "name": "http",
  "containerPort": 5001,
  "hostPort": 5001,
  "protocol": "tcp",
  "appProtocol": "http"
}
```

Service Connect do ECS Service:

```json
{
  "enabled": true,
  "namespace": "fcgames.local",
  "services": [
    {
      "portName": "http",
      "discoveryName": "fcg-users-service",
      "clientAliases": [
        {
          "port": 5001,
          "dnsName": "fcg-users-service"
        }
      ]
    }
  ]
}
```

### Catalog

```json
{
  "name": "http",
  "containerPort": 5002,
  "hostPort": 5002,
  "protocol": "tcp",
  "appProtocol": "http"
}
```

Service Connect:

```json
{
  "enabled": true,
  "namespace": "fcgames.local",
  "services": [
    {
      "portName": "http",
      "discoveryName": "fcg-catalog-service",
      "clientAliases": [
        {
          "port": 5002,
          "dnsName": "fcg-catalog-service"
        }
      ]
    }
  ]
}
```

Esses `portName` precisam coincidir exatamente com os nomes dos `portMappings`.

## 7. Criar Prometheus e Grafana

Defina:

```bash
export PRIVATE_SUBNET_ID_1=subnet-xxxxxxxx
export PRIVATE_SUBNET_ID_2=subnet-yyyyyyyy
export SG_OBSERVABILITY_ID=sg-xxxxxxxx
export CLUSTER_NAME=fcgames-cluster
export AWS_REGION=sa-east-1
```

Depois:

```bash
./aws/create-services.sh
```

O Prometheus é configurado como cliente Service Connect e consulta:

```text
http://fcg-users-service:5001/metrics
http://fcg-catalog-service:5002/metrics
```

## 8. ALB para Grafana

Crie um ALB público e encaminhe a porta 80/443 para o target group do serviço `fcg-grafana` na porta 3000.

Não exponha o Prometheus 9090 publicamente. O ALB do Grafana deve ser a entrada externa da observabilidade.

## 9. Dashboard

Substitua o arquivo:

```text
grafana/dashboards/fcgames-observability.json
```

pelo seu dashboard atual. Ele será copiado para a imagem e provisionado automaticamente pelo Grafana.

## 10. Teste final

No Prometheus, abra:

```text
http://<PROMETHEUS-INTERNAL>:9090/targets
```

Os targets devem aparecer como `UP`:

- `fcg-users-service`
- `fcg-catalog-service`

No Grafana, o datasource `Prometheus` já aponta para:

```text
http://prometheus:9090
```

O Service Connect configura endpoints por nome e porta; portanto o container do Grafana pode usar `prometheus:9090` quando o serviço Prometheus também estiver no namespace.

## Observação sobre persistência

A configuração acima é adequada para uma primeira implantação/POC. O armazenamento da task Fargate é efêmero por padrão. Se você precisar preservar o histórico do Prometheus entre substituições de tasks, considere EFS/EBS ou migrar para Amazon Managed Service for Prometheus. O Fargate suporta EFS para armazenamento persistente.
