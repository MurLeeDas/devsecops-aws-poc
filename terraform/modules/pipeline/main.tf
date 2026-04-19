data "aws_caller_identity" "current" {}

# ── S3 Artifact Bucket ───────────────────────────────────────
# WHY: CodePipeline passes build artifacts (Docker image tag,
# imagedefinitions.json) between stages via S3.
# Think of it as a conveyor belt between pipeline stages.

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CodeStar Connection (GitHub) ─────────────────────────────
# WHY: CodePipeline needs secure OAuth access to GitHub.
# CodeStar Connections is AWS's managed way to do this.
# IMPORTANT: After terraform apply, you must manually authorise
# this connection in AWS Console → Developer Tools → Connections.
# Status will show "Pending" until you click Authorise.

resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-github"
  provider_type = "GitHub"
}

# ── CodeBuild Project ────────────────────────────────────────
# WHY: CodeBuild is your managed build server.
# It runs your buildspec.yml — builds the Docker image,
# runs SAST with Bandit, scans with Trivy, pushes to ECR.
# No build server to manage — AWS handles it.

resource "aws_codebuild_project" "main" {
  name          = "${var.project_name}-build"
  description   = "Builds, scans, and pushes Docker image to ECR"
  build_timeout = 20
  service_role  = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
    # WHY CODEPIPELINE type: Artifacts are passed directly
    # from/to pipeline stages — no manual S3 path needed.
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
    # WHY privileged_mode: Required to run Docker commands
    # inside CodeBuild. Without it, `docker build` fails.

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REGISTRY"
      value = split("/", var.ecr_repo_url)[0]
      # Extracts the registry prefix: 123456789.dkr.ecr.ap-south-1.amazonaws.com
    }

    environment_variable {
      name  = "ECR_REPOSITORY"
      value = var.ecr_repo_name
    }

    environment_variable {
      name  = "ECS_CLUSTER"
      value = var.ecs_cluster_name
    }

    environment_variable {
      name  = "ECS_SERVICE"
      value = var.ecs_service_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
    # WHY: Uses the buildspec.yml in your GitHub repo root.
    # Keeps build config with code — version controlled, auditable.
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.project_name}"
      stream_name = "build"
    }
  }
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/codebuild/${var.project_name}"
  retention_in_days = 14
}

# ── CodePipeline ─────────────────────────────────────────────
# WHY: CodePipeline is the orchestrator — it watches your GitHub
# branch, triggers CodeBuild on every push, and deploys to ECS
# only when the build passes. It's the glue between all stages.

resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-pipeline"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # Stage 1: Source — watches GitHub for changes
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
        # WHY DetectChanges: Pipeline triggers automatically
        # on push. No manual triggering needed.
      }
    }
  }

  # Stage 2: Build — runs CodeBuild (SAST + Docker build + Trivy + ECR push)
  stage {
    name = "Build"

    action {
      name             = "Build_and_Scan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  # Stage 3: Deploy — updates ECS service with new image
  stage {
    name = "Deploy"

    action {
      name            = "Deploy_to_ECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
        # WHY imagedefinitions.json: This file (produced by buildspec.yml)
        # tells ECS exactly which image tag to deploy.
        # Format: [{"name":"container-name","imageUri":"ecr-url:tag"}]
      }
    }
  }
}
