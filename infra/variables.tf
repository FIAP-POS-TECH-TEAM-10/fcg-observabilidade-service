variable "aws_region" {
  default = "sa-east-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "public_key" {
  type        = string
  description = "Chave SSH pública para acesso à EC2"
}