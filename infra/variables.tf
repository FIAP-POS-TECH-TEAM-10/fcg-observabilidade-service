variable "aws_region" {
  default = "sa-east-1"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro" # <--- Alterar para t3.micro
  description = "Instância EC2 para a stack de monitoramento"
}