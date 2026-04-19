output "pipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.main.name
}

output "pipeline_arn" {
  description = "CodePipeline ARN"
  value       = aws_codepipeline.main.arn
}

output "codebuild_project_name" {
  description = "CodeBuild project name"
  value       = aws_codebuild_project.main.name
}

output "artifact_bucket_name" {
  description = "S3 artifact bucket name"
  value       = aws_s3_bucket.artifacts.bucket
}

output "codestar_connection_arn" {
  description = "CodeStar connection ARN — must be manually authorised in AWS Console after apply"
  value       = aws_codestarconnections_connection.github.arn
}
