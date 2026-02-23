# public endpoint
output "app_url" {
  description = "Public URL of the application (ALB DNS). Access /health for health check."
  value       = "http://${aws_lb.alb.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.alb.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — used in docker push and ECS task definition"
  value       = aws_ecr_repository.php_app.repository_url
}

output "ecr_registry" {
  description = "ECR registry URL (account-level)"
  value       = local.ecr_registry
}

output "ecs_cluster_name" {
  description = "ECS cluster name — used by deploy scripts"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name — used by deploy scripts"
  value       = aws_ecs_service.php_app.name
}

output "ecs_task_definition_family" {
  description = "ECS task definition family"
  value       = aws_ecs_task_definition.php_app.family
}
