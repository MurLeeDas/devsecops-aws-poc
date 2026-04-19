output "ecs_task_role_arn" {
  description = "ARN of the ECS task role (used by the app at runtime)"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role (used to start tasks)"
  value       = aws_iam_role.ecs_execution.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild.arn
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline.arn
}
