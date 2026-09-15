# Busca a AMI Ubuntu 22.04 LTS mais recente
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Security Group com portas das ferramentas liberadas
resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Acesso para Prometheus, Grafana, Zabbix e SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Zabbix Web"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Zabbix Server Traps/Agents"
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância EC2 (Recomendado t3.medium no mínimo para rodar toda essa stack)
resource "aws_instance" "monitoring_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # 100% elegível ao Free Tier (750h/mês)
  

  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  root_block_device {
    volume_size = 30 # Limite gratuito de disco SSD (gp3)
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # 1. Configurar SWAP de 2GB para não estourar a memória da t2.micro
              fallocate -l 2G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              # 2. Instalar Docker e Docker Compose
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release
              
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "Monitoring-Server-FreeTier"
  }
}

output "ec2_public_ip" {
  value       = aws_instance.monitoring_server.public_ip
  description = "IP Público da instância EC2"
}