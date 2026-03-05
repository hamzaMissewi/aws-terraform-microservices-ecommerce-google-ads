output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.go_app.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.go_app.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.go_app.id
}

output "docker_image_id" {
  description = "Docker image ID"
  value       = docker_image.go_app.image_id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.go_app.name
}

output "autoscaling_target_arn" {
  description = "ARN of the auto scaling target"
  value       = aws_appautoscaling_target.go_app.arn
}
