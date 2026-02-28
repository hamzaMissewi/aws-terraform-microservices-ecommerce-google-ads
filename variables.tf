variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ecommerce-platform"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "owner_email" {
  description = "Owner email for tagging"
  type        = string
  default     = "admin@example.com"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

# Security Group Rules
variable "alb_security_group_rules" {
  description = "Security group rules for Application Load Balancer"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from internet"
    },
    {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from internet"
    }
  ]
}

variable "ecs_security_group_rules" {
  description = "Security group rules for ECS services"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      type        = "ingress"
      from_port   = 3000
      to_port     = 5000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Application ports"
    }
  ]
}

variable "rds_security_group_rules" {
  description = "Security group rules for RDS instances"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      type        = "ingress"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "MySQL from VPC"
    },
    {
      type        = "ingress"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "PostgreSQL from VPC"
    }
  ]
}

variable "redis_security_group_rules" {
  description = "Security group rules for Redis"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      type        = "ingress"
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Redis from VPC"
    }
  ]
}

# ECS Service Configuration
variable "services" {
  description = "ECS service configurations"
  type = list(object({
    name           = string
    image          = string
    port           = number
    cpu            = number
    memory         = number
    desired_count  = number
    min_capacity   = number
    max_capacity   = number
    health_check_path = string
    environment_variables = map(string)
    secrets = map(string)
  }))
  default = [
    {
      name           = "user-service"
      image          = "nginx:latest"
      port           = 3000
      cpu            = 256
      memory         = 512
      desired_count  = 2
      min_capacity   = 1
      max_capacity   = 5
      health_check_path = "/health"
      environment_variables = {
        NODE_ENV = "production"
        PORT = "3000"
      }
      secrets = {}
    },
    {
      name           = "product-service"
      image          = "nginx:latest"
      port           = 3001
      cpu            = 256
      memory         = 512
      desired_count  = 2
      min_capacity   = 1
      max_capacity   = 5
      health_check_path = "/health"
      environment_variables = {
        NODE_ENV = "production"
        PORT = "3001"
      }
      secrets = {}
    },
    {
      name           = "order-service"
      image          = "nginx:latest"
      port           = 3002
      cpu            = 256
      memory         = 512
      desired_count  = 2
      min_capacity   = 1
      max_capacity   = 5
      health_check_path = "/health"
      environment_variables = {
        NODE_ENV = "production"
        PORT = "3002"
      }
      secrets = {}
    }
  ]
}

# Database Configuration
variable "rds_instances" {
  description = "RDS instance configurations"
  type = list(object({
    identifier          = string
    engine              = string
    engine_version      = string
    instance_class      = string
    allocated_storage   = number
    storage_type        = string
    storage_encrypted   = bool
    database_name       = string
    username            = string
    password            = string
    port                = number
    multi_az            = bool
    publicly_accessible = bool
    backup_retention_period = number
    backup_window          = string
    maintenance_window    = string
    skip_final_snapshot    = bool
    deletion_protection    = bool
  }))
  default = [
    {
      identifier          = "ecommerce-users-db"
      engine              = "postgres"
      engine_version      = "15.4"
      instance_class      = "db.t3.micro"
      allocated_storage   = 20
      storage_type        = "gp2"
      storage_encrypted   = true
      database_name       = "users"
      username            = "postgres"
      password            = "changeme123!"
      port                = 5432
      multi_az            = false
      publicly_accessible = false
      backup_retention_period = 7
      backup_window          = "03:00-04:00"
      maintenance_window    = "sun:04:00-sun:05:00"
      skip_final_snapshot    = true
      deletion_protection    = false
    },
    {
      identifier          = "ecommerce-orders-db"
      engine              = "mysql"
      engine_version      = "8.0"
      instance_class      = "db.t3.micro"
      allocated_storage   = 20
      storage_type        = "gp2"
      storage_encrypted   = true
      database_name       = "orders"
      username            = "admin"
      password            = "changeme123!"
      port                = 3306
      multi_az            = false
      publicly_accessible = false
      backup_retention_period = 7
      backup_window          = "03:00-04:00"
      maintenance_window    = "sun:04:00-sun:05:00"
      skip_final_snapshot    = true
      deletion_protection    = false
    }
  ]
  sensitive = true
}

variable "documentdb_config" {
  description = "DocumentDB configuration"
  type = object({
    cluster_identifier = string
    instance_class     = string
    instance_count     = number
    master_username    = string
    master_password    = string
    port               = number
    backup_retention_period = number
    preferred_backup_window = string
    preferred_maintenance_window = string
    skip_final_snapshot = bool
    deletion_protection = bool
  })
  default = {
    cluster_identifier = "ecommerce-products-docdb"
    instance_class     = "db.t3.medium"
    instance_count     = 1
    master_username    = "admin"
    master_password    = "changeme123!"
    port               = 27017
    backup_retention_period = 7
    preferred_backup_window = "03:00-04:00"
    preferred_maintenance_window = "sun:04:00-sun:05:00"
    skip_final_snapshot = true
    deletion_protection = false
  }
  sensitive = true
}

variable "redis_config" {
  description = "ElastiCache Redis configuration"
  type = object({
    cluster_id           = string
    node_type            = string
    num_cache_nodes      = number
    port                 = number
    parameter_group_name = string
    engine               = string
    engine_version       = string
    automatic_failover_enabled = bool
    multi_az_enabled     = bool
    at_rest_encryption_enabled = bool
    transit_encryption_enabled = bool
    auth_token           = string
  })
  default = {
    cluster_id           = "ecommerce-redis"
    node_type            = "cache.t3.micro"
    num_cache_nodes      = 1
    port                 = 6379
    parameter_group_name = "default.redis7"
    engine               = "redis"
    engine_version       = "7.0"
    automatic_failover_enabled = false
    multi_az_enabled     = false
    at_rest_encryption_enabled = true
    transit_encryption_enabled = true
    auth_token           = "changeme123!"
  }
  sensitive = true
}

# Auto Scaling
variable "enable_auto_scaling" {
  description = "Enable auto scaling for ECS services"
  type        = bool
  default     = true
}

# Monitoring
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = true
}

variable "sns_email_endpoint" {
  description = "Email endpoint for SNS notifications"
  type        = string
  default     = "admin@example.com"
}

# Backup and Maintenance
variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# CI/CD
variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/username/ecommerce-platform.git"
}

variable "github_branch" {
  description = "GitHub branch for CI/CD"
  type        = string
  default     = "main"
}

variable "codebuild_image" {
  description = "CodeBuild build image"
  type        = string
  default     = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
}

# API Gateway
variable "api_routes" {
  description = "API Gateway routes configuration"
  type = list(object({
    path         = string
    method       = string
    service_name = string
    port         = number
  }))
  default = [
    {
      path         = "/users"
      method       = "GET"
      service_name = "user-service"
      port         = 3000
    },
    {
      path         = "/products"
      method       = "GET"
      service_name = "product-service"
      port         = 3001
    },
    {
      path         = "/orders"
      method       = "GET"
      service_name = "order-service"
      port         = 3002
    }
  ]
}

# Domain and SSL
variable "domain_name" {
  description = "Custom domain name"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = ""
}

# WAF
variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = false
}

variable "waf_rules" {
  description = "WAF rules configuration"
  type = list(object({
    name        = string
    type        = string
    priority    = number
    action      = string
    metric_name = string
  }))
  default = [
    {
      name        = "SQLInjectionProtection"
      type        = "SQL_INJECTION"
      priority    = 1
      action      = "block"
      metric_name = "SQLInjectionProtection"
    },
    {
      name        = "XSSProtection"
      type        = "XSS"
      priority    = 2
      action      = "block"
      metric_name = "XSSProtection"
    }
  ]
}

# Google Ads Configuration
variable "google_ads_client_id" {
  description = "Google Ads API client ID"
  type        = string
  sensitive   = true
}

variable "google_ads_client_secret" {
  description = "Google Ads API client secret"
  type        = string
  sensitive   = true
}

variable "google_ads_refresh_token" {
  description = "Google Ads API refresh token"
  type        = string
  sensitive   = true
}

variable "google_ads_developer_token" {
  description = "Google Ads API developer token"
  type        = string
  sensitive   = true
}

variable "campaign_monitor_schedule" {
  description = "Cron expression for campaign monitoring"
  type        = string
  default     = "rate(15 minutes)"
}

variable "bid_optimizer_schedule" {
  description = "Cron expression for bid optimization"
  type        = string
  default     = "rate(1 hour)"
}

variable "optimization_interval" {
  description = "Optimization interval in minutes"
  type        = string
  default     = "60"
}

# Deep Seek API Configuration
variable "deepseek_api_key" {
  description = "Deep Seek API key for AI services"
  type        = string
  sensitive   = true
}

variable "deepseek_api_url" {
  description = "Deep Seek API endpoint URL"
  type        = string
  default     = "https://api.deepseek.com/v1"
}
