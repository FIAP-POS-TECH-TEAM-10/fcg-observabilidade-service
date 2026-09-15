# O pipeline lê este output para saber a quem enviar o comando do SSM.
output "instance_id" {
  value       = aws_instance.monitoring_server.id
  description = "ID da instância EC2 de monitoramento"
}

output "ec2_public_ip" {
  value       = aws_instance.monitoring_server.public_ip
  description = "IP Público da instância EC2"
}

output "grafana_url" {
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000"
  description = "Endereço do Grafana"
}

output "zabbix_url" {
  value       = "http://${aws_instance.monitoring_server.public_ip}:8080"
  description = "Endereço do Zabbix Web (login padrão: Admin / zabbix)"
}
