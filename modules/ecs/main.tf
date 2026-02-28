terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.alb_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

# ALB Target Groups
resource "aws_lb_target_group" "services" {
  for_each = { for service in var.services : service.name => service }

  name     = "${var.project_name}-${each.key}-tg"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = each.value.health_check_path
    timeout             = 5
    unhealthy_threshold = 2
  }

  target_type = "ip"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-tg"
    }
  )
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 - Not Found"
      status_code  = "404"
    }
  }
}

# ALB Listener Rules for Services
resource "aws_lb_listener_rule" "services" {
  for_each = { for service in var.services : service.name => service }

  listener_arn = aws_lb_listener.main.arn
  priority     = index(var.services, each.value) + 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-rule"
    }
  )
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "services" {
  for_each = { for service in var.services : service.name => service }

  family                   = "${var.project_name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = each.key
      image = each.value.image

      portMappings = [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ]

      environment = [
        for key, value in each.value.environment_variables : {
          name  = key
          value = value
        }
      ]

      secrets = [
        for key, value in each.value.secrets : {
          name      = key
          valueFrom = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-${each.key}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}${each.value.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-task"
    }
  )
}

# ECS Services
resource "aws_ecs_service" "services" {
  for_each = { for service in var.services : service.name => service }

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count
  launch_type      = "FARGATE"

  network_configuration {
    subnets          = var.ecs_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  depends_on = [aws_lb_listener.main]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-service"
    }
  )
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "services" {
  for_each = var.enable_auto_scaling ? { for service in var.services : service.name => service } : {}

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "cpu_scale_up" {
  for_each = var.enable_auto_scaling ? { for service in var.services : service.name => service } : {}

  name               = "${var.project_name}-${each.key}-cpu-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-cpu-scale-up"
    }
  )
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "memory_scale_up" {
  for_each = var.enable_auto_scaling ? { for service in var.services : service.name => service } : {}

  name               = "${var.project_name}-${each.key}-memory-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-memory-scale-up"
    }
  )
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "services" {
  for_each = { for service in var.services : service.name => service }

  name              = "/ecs/${var.project_name}-${each.key}"
  retention_in_days = 14

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-logs"
    }
  )
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-task-role"
    }
  )
}

# VPC Link for API Gateway
resource "aws_vpc_link" "main" {
  name                = "${var.project_name}-vpc-link"
  security_group_ids  = [var.ecs_security_group_id]
  subnet_ids          = var.ecs_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-link"
    }
  )
}
