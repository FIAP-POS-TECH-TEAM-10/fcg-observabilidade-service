output "instance_id" {
  value       = aws_instance.monitoring_server.id
  description = "ID da instancia EC2 para conexao via SSM"
}