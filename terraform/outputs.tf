output "ecr_repository_url" {
  description = "ECR repository URL — use this in GitHub Actions secrets"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "alb_dns_name" {
  description = "Load balancer URL — open this in browser to see your app"
  value       = module.ecs.alb_dns_name
}

output "pipeline_name" {
  description = "CodePipeline name"
  value       = module.pipeline.pipeline_name
}

output "codebuild_project_name" {
  description = "CodeBuild project name"
  value       = module.pipeline.codebuild_project_name
}
