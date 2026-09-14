# 1. Busca o Cluster ECS que já está criado na AWS
data "aws_ecs_cluster" "existing_cluster" {
  cluster_name = "fcg-cluster-fiap"
}

# 2. Definição da Task (Task Definition)
# Lê o seu arquivo task-definition.json dinamicamente com Prometheus e Grafana
resource "aws_ecs_task_definition" "app_task" {
  family                   = "fcg-observability-service-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "512"
  memory                   = "512"

  container_definitions = jsonencode(
    jsondecode(file("${path.module}/../.aws/task-definition.json")).containerDefinitions
  )
}

# 3. CloudWatch Log Group (Onde as ferramentas escrevem os logs)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/fcg-observability-service"
  retention_in_days = 7
}

# 4. Serviço ECS (Vinculado diretamente ao cluster que já existe)
resource "aws_ecs_service" "observability_service" {
  name            = var.service_name
  cluster         = data.aws_ecs_cluster.existing_cluster.id # Usa o ID do cluster existente
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  tags = {
    Environment = "FreeTier-Study"
  }
}
