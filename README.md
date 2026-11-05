# fcg-observabilidade-service

**Este repositório foi aposentado.** A observabilidade (Prometheus + Grafana) agora roda dentro do cluster EKS, junto com os serviços, e não numa EC2 própria.

- Onde está: [`fcg-orchestration/k8s/eks/observability`](https://github.com/FIAP-POS-TECH-TEAM-10/fcg-orchestration/tree/main/k8s/eks/observability) (manifests, `prometheus.yml` e o dashboard "FCGames — Observabilidade").
- Como abrir: ao ligar o cluster (workflow "Ligar cluster EKS"), o Grafana fica em `http://<alb>/grafana`, somente leitura. A URL aparece no resumo do workflow e no fim do `scripts/eks-up.sh`.
- Para editar o dashboard: `kubectl port-forward svc/grafana 3000:80 -n fcgames` e entre como `admin` (a senha é o secret `GRAFANA_PASSWORD`). Depois exporte o JSON e atualize `fcgames-observability.json` no `fcg-orchestration`.

O que foi removido daqui: a EC2 com docker-compose (Grafana, Prometheus e Zabbix), o Terraform e o pipeline que a recriava. O Zabbix saiu de vez. O histórico git continua disponível.
