variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "ecr_repo_url" {
  description = "Full ECR repository URL for the container image"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from network module"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "ecs_task_role_arn" {
  description = "IAM role ARN for ECS task (runtime permissions)"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "IAM role ARN for ECS execution (pull image, write logs)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 5000
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
