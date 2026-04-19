variable "project_name" {
  description = "Project identifier used in resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for metrics"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name for metrics"
  type        = string
}

variable "pipeline_name" {
  description = "CodePipeline name for failure alarms"
  type        = string
}

variable "alert_email" {
  description = "Email address for pipeline failure notifications"
  type        = string
}
