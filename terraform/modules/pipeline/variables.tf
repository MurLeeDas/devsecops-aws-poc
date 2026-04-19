variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "github_owner" {
  description = "GitHub username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch to trigger the pipeline"
  type        = string
}

variable "ecr_repo_url" {
  description = "Full ECR repository URL"
  type        = string
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name from ecs module"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name from ecs module"
  type        = string
}

variable "codebuild_role_arn" {
  description = "IAM role ARN for CodeBuild"
  type        = string
}

variable "codepipeline_role_arn" {
  description = "IAM role ARN for CodePipeline"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
