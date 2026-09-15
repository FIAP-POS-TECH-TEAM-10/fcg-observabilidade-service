FROM grafana/grafana:13.2.1

# Dashboards vão em /etc/grafana (não em /var/lib/grafana/dashboards) porque
# /var/lib/grafana é onde o docker-compose.yml monta o volume persistente
# grafana_data -- ver comentário em provisioning/dashboards/dashboards.yml.
COPY provisioning /etc/grafana/provisioning
COPY dashboards /etc/grafana/provisioning/dashboards-data

EXPOSE 3000
