terraform {
  required_version = ">= 1.15.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
  
  backend "s3" {
    bucket = "ecommerce-platform-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
    }
  }
}

# Data sources for availability zones and AMIs
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Random resources for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  
  availability_zones = data.aws_availability_zones.available.names
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Security Module
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id = module.vpc.vpc_id
  
  # Security group rules
  alb_security_group_rules = var.alb_security_group_rules
  ecs_security_group_rules = var.ecs_security_group_rules
  rds_security_group_rules = var.rds_security_group_rules
  redis_security_group_rules = var.redis_security_group_rules
  
  tags = {
    Name = "${var.project_name}-security"
  }
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  cluster_name = "${var.project_name}-cluster"
  
  # Application Load Balancer
  alb_security_group_id = module.security.alb_security_group_id
  alb_subnet_ids        = module.vpc.public_subnet_ids
  
  # ECS Services
  ecs_security_group_id = module.security.ecs_security_group_id
  ecs_subnet_ids        = module.vpc.private_subnet_ids
  
  # Service configurations
  services = var.services
  
  # Auto Scaling
  enable_auto_scaling = var.enable_auto_scaling
  
  tags = {
    Name = "${var.project_name}-ecs"
  }
  
  depends_on = [module.security, module.vpc]
}

# Database Module
module "databases" {
  source = "./modules/databases"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id             = module.vpc.vpc_id
  database_subnet_ids = module.vpc.database_subnet_ids
  
  # RDS configurations
  rds_instances = var.rds_instances
  
  # DocumentDB configuration
  documentdb_config = var.documentdb_config
  
  # ElastiCache configuration
  redis_config = var.redis_config
  
  # Security
  rds_security_group_id = module.security.rds_security_group_id
  redis_security_group_id = module.security.redis_security_group_id
  
  # Backup and maintenance
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  tags = {
    Name = "${var.project_name}-databases"
  }
  
  depends_on = [module.security, module.vpc]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  # ECS Cluster
  ecs_cluster_name = module.ecs.cluster_name
  
  # RDS instances
  rds_instance_identifiers = module.databases.rds_instance_identifiers
  
  # ElastiCache
  redis_cluster_id = module.databases.redis_cluster_id
  
  # CloudWatch
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  enable_xray_tracing    = var.enable_xray_tracing
  
  # SNS for alerts
  sns_email_endpoint = var.sns_email_endpoint
  
  tags = {
    Name = "${var.project_name}-monitoring"
  }
  
  depends_on = [module.ecs, module.databases]
}

# CI/CD Module
module "ci_cd" {
  source = "./modules/ci-cd"
  
  project_name = var.project_name
  environment  = var.environment
  
  # GitHub connection
  github_repo_url = var.github_repo_url
  github_branch   = var.github_branch
  
  # CodeBuild
  codebuild_image = var.codebuild_image
  
  # CodePipeline
  pipeline_name = "${var.project_name}-pipeline"
  
  # IAM roles
  codepipeline_role_arn = module.security.codepipeline_role_arn
  codebuild_role_arn    = module.security.codebuild_role_arn
  
  tags = {
    Name = "${var.project_name}-cicd"
  }
  
  depends_on = [module.security]
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name = var.project_name
  environment  = var.environment
  
  # API Gateway configuration
  api_name = "${var.project_name}-api"
  
  # Integration with ECS
  vpc_link_id = module.ecs.vpc_link_id
  
  # Routes and integrations
  api_routes = var.api_routes
  
  # Custom domain
  domain_name = var.domain_name
  certificate_arn = var.certificate_arn
  
  tags = {
    Name = "${var.project_name}-api"
  }
  
  depends_on = [module.ecs]
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Origin configuration
  origin_domain_name = module.api_gateway.api_domain_name
  origin_id          = "${var.project_name}-api-origin"
  
  # Custom domain
  domain_name = var.domain_name
  certificate_arn = var.certificate_arn
  
  # WAF
  enable_waf = var.enable_waf
  waf_rules   = var.waf_rules
  
  tags = {
    Name = "${var.project_name}-cloudfront"
  }
  
  depends_on = [module.api_gateway]
}

# Route53 Module (if custom domain is used)
module "route53" {
  count = var.domain_name != "" ? 1 : 0
  source = "./modules/route53"
  
  project_name = var.project_name
  environment  = var.environment
  
  domain_name = var.domain_name
  
  # Records
  api_record_name    = "api"
  www_record_name    = "www"
  cloudfront_domain  = module.cloudfront.cloudfront_domain_name
  api_gateway_domain = module.api_gateway.api_domain_name
  
  tags = {
    Name = "${var.project_name}-route53"
  }
  
  depends_on = [module.cloudfront, module.api_gateway]
}
