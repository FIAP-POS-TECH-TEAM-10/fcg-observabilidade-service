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

# Key Pair para acesso SSH via chave pública
resource "aws_key_pair" "deployer" {
  key_name   = "monitoring-key"
  public_key = var.public_key
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Acesso para Grafana, Prometheus, Zabbix e SSH"

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
    cidr_blocks = var.grafana_allowed_cidrs
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.prometheus_allowed_cidrs
  }

  ingress {
    description = "Zabbix Web"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.zabbix_allowed_cidrs
  }

  # Porta que os agentes Zabbix usam para enviar dados ao server.
  ingress {
    description = "Zabbix Server Traps/Agents"
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = var.zabbix_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# IAM: sem esta role o agente do SSM não consegue registrar a instância, e o
# `aws ssm send-command` do pipeline falha com InvalidInstanceId.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "monitoring" {
  name = "monitoring-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# O ec2_sd_configs do Prometheus descobre as APIs consultando a API da EC2.
resource "aws_iam_role_policy" "ec2_discovery" {
  name = "prometheus-ec2-discovery"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances", "ec2:DescribeAvailabilityZones"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "monitoring-server-profile"
  role = aws_iam_role.monitoring.name
}

# Instância EC2
resource "aws_instance" "monitoring_server" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = aws_key_pair.deployer.key_name
  iam_instance_profile = aws_iam_instance_profile.monitoring.name

  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  root_block_device {
    volume_size = 30 # Limite gratuito de disco SSD (gp3)
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # 1. SWAP de 2GB: folga para a t2.micro não estourar em picos
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

              mkdir -p /opt/observability
              EOF

  tags = {
    Name = "Monitoring-Server-FreeTier"
  }
}
