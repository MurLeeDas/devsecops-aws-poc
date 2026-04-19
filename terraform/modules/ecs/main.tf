data "aws_caller_identity" "current" {}

# ── CloudWatch Log Group ─────────────────────────────────────
# WHY: All container stdout/stderr goes here automatically.
# Without this, logs vanish when a task stops. Never debug blind.

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
}

# ── Security Group: ALB ──────────────────────────────────────
# WHY: ALB only accepts HTTP traffic from the internet (port 80).
# Nothing else is allowed in. This is your public-facing door.

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound to ALB only"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── Security Group: ECS Tasks ────────────────────────────────
# WHY: ECS tasks ONLY accept traffic from the ALB — not the internet.
# This is defence in depth. Even if someone knows your task IP,
# they cannot reach it directly. Only ALB can talk to your app.

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow inbound only from ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-sg" }
}

# ── Application Load Balancer ────────────────────────────────
# WHY: ALB is your traffic manager. It receives requests on port 80
# and forwards them to healthy ECS tasks. If a task crashes,
# ALB automatically stops sending traffic to it — zero downtime.

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  # WHY target_type = ip: Fargate tasks have no EC2 instance.
  # Traffic goes directly to the task's private IP. Cleaner, faster.

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    # WHY /health endpoint: Dedicated health check = faster detection
    # of unhealthy tasks. App code owns this — not a generic ping.
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── ECS Cluster ──────────────────────────────────────────────
# WHY Fargate: No EC2 servers to patch, scale, or manage.
# You pay only when tasks are running. Perfect for POC and production.

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
    # WHY: Container Insights = automatic CPU/memory metrics
    # per task in CloudWatch. Clients see this in the dashboard.
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── ECS Task Definition ──────────────────────────────────────
# WHY: Task definition = the blueprint for your container.
# It says: use this image, give it this much CPU/memory,
# expose this port, write logs here. ECS uses this to start tasks.

resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # WHY awsvpc: Each task gets its own elastic network interface
  # and private IP. Fine-grained security group control per task.
  cpu                      = 256   # 0.25 vCPU — free tier friendly
  memory                   = 512   # 512 MB
  task_role_arn            = var.ecs_task_role_arn
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([{
    name      = var.project_name
    image     = "${var.ecr_repo_url}:latest"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "ENV",         value = var.environment },
      { name = "APP_VERSION", value = "1.0.0" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.project_name}"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.container_port}/health')\" || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])
}

# ── ECS Service ──────────────────────────────────────────────
# WHY: The service is what keeps your app ALWAYS running.
# If a task crashes, the service automatically starts a new one.
# desired_count = 1 means: always keep 1 task alive.

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
    # WHY false: Tasks are in private subnets.
    # They go out via NAT, never directly exposed to internet.
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.project_name
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  # WHY these values: During a deployment, ECS starts a new task
  # before stopping the old one (rolling update).
  # 50% min = at least 1 task always running during deploy.
  # 200% max = temporarily run 2 tasks during rollover.
  # Zero-downtime deployments — show this to clients.

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
    # WHY: CodePipeline updates the task definition on each deploy.
    # Without this, Terraform would revert it on every `terraform apply`.
  }
}
