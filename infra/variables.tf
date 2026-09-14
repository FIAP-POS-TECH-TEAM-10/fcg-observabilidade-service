# --- VARIÁVEIS GLOBAIS ---
variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "service_name" {
  type    = string
  default = "fcg-observability-service"
}

variable "app_port" {
  type    = number
  default = 3000 # Porta exposta do container 
}

variable "cluster_name" {
  type    = string
  default = "fcg-cluster-fiap"
}