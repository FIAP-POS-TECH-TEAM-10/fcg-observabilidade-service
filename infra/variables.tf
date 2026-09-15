variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

# t3.micro é o tipo elegível ao free tier em sa-east-1 (não a t2.micro), e é o
# que todas as 6 instâncias da conta já usam. Mesma RAM: 1 GB.
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "grafana_allowed_cidrs" {
  type        = list(string)
  description = "Quem pode abrir o Grafana na porta 3000."
  default     = ["0.0.0.0/0"]
}

# O Prometheus não tem autenticação nenhuma. Deixar aberto expõe todas as
# métricas da stack; restrinja ao seu IP quando precisar depurar.
variable "prometheus_allowed_cidrs" {
  type        = list(string)
  description = "Quem pode abrir o Prometheus na porta 9090."
  default     = ["0.0.0.0/0"]
}

# O Zabbix Web sobe com as credenciais padrão (Admin/zabbix). Restrinja o acesso
# ou troque a senha no primeiro login.
variable "zabbix_allowed_cidrs" {
  type        = list(string)
  description = "Quem pode abrir o Zabbix nas portas 8080 e 10051."
  default     = ["0.0.0.0/0"]
}

variable "public_key" {
  type        = string
  description = "Chave SSH pública para acesso à EC2"
}
