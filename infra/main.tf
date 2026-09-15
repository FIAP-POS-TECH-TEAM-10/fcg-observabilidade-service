# 1. Cria a IAM Role
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Anexa a política gerenciada do SSM à Role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. Cria o Instance Profile que vincula a Role à EC2
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

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
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro" # 100% elegível ao Free Tier (750h/mês)
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]

  root_block_device {
    volume_size = 30 # Limite gratuito de disco SSD (gp3)
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -x

              # 1. Configurar SWAP de 2GB
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

              # 3. Reinicia o SSM Agent (já vem pré-instalado via snap na AMI oficial
              # da Canonical — não precisa reinstalar via .deb). Ele tenta pegar as
              # credenciais da IAM Role pelo IMDS logo nos primeiros segundos do boot,
              # ANTES do user_data rodar, e quando falha nessa primeira tentativa não
              # tenta de novo sozinho (a conta não tem "Default Host Management"
              # configurado como fallback) — por isso a instância nunca fica "Online"
              # no SSM. Reiniciar aqui, no fim do user_data (depois do apt/Docker já
              # terem dado tempo de sobra pro IMDS estabilizar), força uma nova
              # tentativa de credenciais que já funciona.
              snap restart amazon-ssm-agent || systemctl restart amazon-ssm-agent
              EOF

  tags = {
    Name = "Monitoring-Server-FreeTier"
  }
}

output "ec2_public_ip" {
  value       = aws_instance.monitoring_server.public_ip
  description = "IP Público da instância EC2"
}