# Add Go application module to existing infrastructure
module "go_app" {
  source = "./modules/go-app"
  
  project_name = var.project_name
  environment  = var.environment
  aws_region  = var.aws_region
  tags        = var.tags
  
  # ECS Configuration
  ecs_cluster_name = module.ecs.cluster_name
  cpu             = 256
  memory          = 512
  desired_count   = 2
  min_capacity    = 1
  max_capacity    = 5
  container_port  = 4000
  
  # Network Configuration
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_ids = [module.security.go_app_security_group_id]
  
  # Database Configuration
  db_host              = module.rds.db_instance_endpoint
  db_port              = 5432
  db_user              = "postgres"
  db_name              = "transactions"
  db_password_secret_arn = aws_secretsmanager_secret.db_password.arn
  
  # IAM Configuration
  execution_role_arn = module.iam.go_app_execution_role_arn
  task_role_arn       = module.iam.go_app_task_role_arn
  
  # Load Balancer Configuration
  target_group_arn = aws_lb_target_group.go_app.arn
  alb_listener      = aws_lb_listener.main
  
  # Logging Configuration
  log_retention_days = 14
}

# Target Group for Go App
resource "aws_lb_target_group" "go_app" {
  name     = "${var.project_name}-go-app-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    timeout             = 5
    unhealthy_threshold = 2
  }

  target_type = "ip"

  tags = var.tags
}

# ALB Listener Rule for Go App
resource "aws_lb_listener_rule" "go_app" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_app.arn
  }

  condition {
    path_pattern {
      values = ["/go/*"]
    }
  }

  tags = var.tags
}

# Database Password Secret
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-go-db-password"
  description             = "Database password for Go application"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}
