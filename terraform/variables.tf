variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "poc"
}

variable "project_name" {
  description = "Project identifier used in all resource names"
  type        = string
  default     = "devsecops-poc"
}

variable "github_owner" {
  description = "GitHub username"
  type        = string
  default     = "MurLeeDas"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "devsecops-aws-poc"
}

variable "github_branch" {
  description = "Branch to trigger pipeline"
  type        = string
  default     = "main"
}

variable "container_port" {
  description = "Port the Flask app listens on"
  type        = number
  default     = 5000
}

variable "alert_email" {
  description = "Email to receive pipeline failure alerts"
  type        = string
  default     = "muralidoss@outlook.com"
}
