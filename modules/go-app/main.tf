terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Docker image for Go application
resource "docker_image" "go_app" {
  name = "go-transaction-app"
  build {
    context = "${path.cwd}/../../application_code/go_app"
  }
  keep_locally = true
}

# ECS Task Definition for Go App
resource "aws_ecs_task_definition" "go_app" {
  family                   = "${var.project_name}-go-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "go-app"
      image = docker_image.go_app.image_id

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DB_HOST"
          value = var.db_host
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        },
        {
          name  = "DB_USER"
          value = var.db_user
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = var.db_password_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-go-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.tags
}

# ECS Service for Go App
resource "aws_ecs_service" "go_app" {
  name            = "${var.project_name}-go-app"
  cluster         = var.ecs_cluster_name
  task_definition = aws_ecs_task_definition.go_app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "go-app"
    container_port   = var.container_port
  }

  depends_on = [var.alb_listener]

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "go_app" {
  name              = "/ecs/${var.project_name}-go-app"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "go_app" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.go_app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  tags               = var.tags
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "go_app_cpu" {
  name               = "${var.project_name}-go-app-cpu-scale"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.go_app.resource_id
  scalable_dimension = aws_appautoscaling_target.go_app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.go_app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "go_app_memory" {
  name               = "${var.project_name}-go-app-memory-scale"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.go_app.resource_id
  scalable_dimension = aws_appautoscaling_target.go_app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.go_app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
