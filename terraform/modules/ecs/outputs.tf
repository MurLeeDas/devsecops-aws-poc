output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "ALB DNS name — open in browser to see your app running"
  value       = aws_lb.main.dns_name
}

output "task_definition_arn" {
  description = "Latest ECS task definition ARN"
  value       = aws_ecs_task_definition.app.arn
}
