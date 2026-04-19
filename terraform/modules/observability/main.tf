# ── SNS Alert Topic ──────────────────────────────────────────
# WHY: SNS is your notification bus. Alarms publish here,
# your email receives it. One topic, many subscribers.
# In production — this could also trigger PagerDuty or Slack.

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # IMPORTANT: After terraform apply, check your email
  # and click the AWS confirmation link to activate alerts.
}

# ── CloudWatch Alarm: ECS CPU High ──────────────────────────
# WHY: If CPU > 80% for 2 consecutive periods, something is wrong.
# Either the app is under heavy load or stuck in a loop.
# Alert fires → you investigate → client sees proactive monitoring.

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilisation exceeded 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

# ── CloudWatch Alarm: ECS Memory High ────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS memory utilisation exceeded 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

# ── CloudWatch Alarm: ECS Running Task Count ─────────────────
# WHY: If running task count drops to 0, your app is down.
# This is your most critical alarm — fires immediately.

resource "aws_cloudwatch_metric_alarm" "ecs_tasks_zero" {
  alarm_name          = "${var.project_name}-no-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "CRITICAL: No ECS tasks are running — app is down"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
  # WHY breaching: If metrics stop arriving (task crashed),
  # treat it as an alarm, not as unknown. Fail safe.

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

# ── CloudWatch Alarm: Pipeline Failure ───────────────────────
# WHY: Know immediately when a deployment fails.
# Catch broken builds before clients do.

resource "aws_cloudwatch_metric_alarm" "pipeline_failed" {
  alarm_name          = "${var.project_name}-pipeline-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedPipelines"
  namespace           = "AWS/CodePipeline"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "CodePipeline execution failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    PipelineName = var.pipeline_name
  }
}

# ── CloudWatch Dashboard ─────────────────────────────────────
# WHY: A single-pane view of your entire system health.
# CPU, memory, running tasks, pipeline status — all in one screen.
# This is what you open on a client call to show live system health.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0 
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# DevSecOps POC Dashboard — Built by Murali Doss | DevSecOps Consultant"
        }
      },
      {
        type   = "metric"
        x      = 0 
        y      = 1 
        width  = 8 
        height = 6
        properties = {
          title   = "ECS CPU Utilisation"
          region  = data.aws_region.current.name
          view    = "timeSeries"
          metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]]
          period  = 60
          stat    = "Average"
          yAxis   = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 8 
        y      = 1 
        width  = 8 
        height = 6
        properties = {
          title   = "ECS Memory Utilisation"
          region  = data.aws_region.current.name
          view    = "timeSeries"
          metrics = [["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]]
          period  = 60
          stat    = "Average"
          yAxis   = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 16 
        y      = 1 
        width  = 8 
        height = 6
        properties = {
          title   = "Running ECS Tasks"
          region  = data.aws_region.current.name
          view    = "timeSeries"
          metrics = [["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]]
          period  = 60
          stat    = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0 
        y      = 7 
        width  = 12 
        height = 6
        properties = {
          title   = "Pipeline Executions"
          region  = data.aws_region.current.name
          view    = "timeSeries"
          metrics = [
            ["AWS/CodePipeline", "SucceededPipelines", "PipelineName", var.pipeline_name],
            ["AWS/CodePipeline", "FailedPipelines", "PipelineName", var.pipeline_name]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "alarm"
        x      = 12 
        y      = 7 
        width  = 12 
        height = 6
        properties = {
          title  = "Active Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.ecs_cpu_high.arn,
            aws_cloudwatch_metric_alarm.ecs_memory_high.arn,
            aws_cloudwatch_metric_alarm.ecs_tasks_zero.arn,
            aws_cloudwatch_metric_alarm.pipeline_failed.arn
          ]
        }
      }
    ]
  })

  depends_on = [
    aws_cloudwatch_metric_alarm.ecs_cpu_high,
    aws_cloudwatch_metric_alarm.ecs_memory_high,
    aws_cloudwatch_metric_alarm.ecs_tasks_zero,
    aws_cloudwatch_metric_alarm.pipeline_failed
  ]
}
