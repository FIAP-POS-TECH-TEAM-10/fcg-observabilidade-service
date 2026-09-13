# Lê todos os arquivos YAML da pasta dashboards/
locals {
  dashboard_files = fileset("${path.module}/dashboards", "*.yaml")
}

resource "grafana_dashboard" "dashboards" {
  for_each = local.dashboard_files

  # Converte o conteúdo YAML lido em JSON para a API do Grafana
  config_json = jsonencode(yamldecode(file("${path.module}/dashboards/${each.value}")))
  
  # Garante a sobrescrita de dashboards existentes com o mesmo UID/Title
  overwrite = true
}