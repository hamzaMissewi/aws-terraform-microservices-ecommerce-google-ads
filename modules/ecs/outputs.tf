output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arns" {
  description = "ARNs of the target groups"
  value = {
    for service in var.services : service.name => aws_lb_target_group.services[service.name].arn
  }
}

output "service_names" {
  description = "Names of the ECS services"
  value = {
    for service in var.services : service.name => aws_ecs_service.services[service.name].name
  }
}

output "service_arns" {
  description = "ARNs of the ECS services"
  value = {
    for service in var.services : service.name => aws_ecs_service.services[service.name].id
  }
}

output "task_definition_arns" {
  description = "ARNs of the task definitions"
  value = {
    for service in var.services : service.name => aws_ecs_task_definition.services[service.name].arn
  }
}

output "vpc_link_id" {
  description = "ID of the VPC Link for API Gateway"
  value       = aws_vpc_link.main.id
}

output "vpc_link_arn" {
  description = "ARN of the VPC Link for API Gateway"
  value       = aws_vpc_link.main.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "log_group_names" {
  description = "Names of the CloudWatch log groups"
  value = {
    for service in var.services : service.name => aws_cloudwatch_log_group.services[service.name].name
  }
}
