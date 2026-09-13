variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "grafana_url" {
  type        = string
  description = "URL do Amazon Managed Grafana"
}

variable "grafana_api_key" {
  type        = string
  description = "Token ou API Key de Service Account do Grafana"
  sensitive   = true
}