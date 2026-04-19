# DevSecOps Pipeline on AWS — Production-Grade Reference Architecture

**Built and maintained by [Murali Doss](https://www.linkedin.com/in/dossops/) | DevSecOps & Cloud Consultant**  
*Grameenphone · Odido/T-Mobile Netherlands · Comcast*

---

## Overview

This repository is a fully working, production-grade DevSecOps pipeline deployed on AWS using Terraform. It demonstrates end-to-end automation from code commit to live deployment, with security gates at every stage.

Every resource in this architecture is provisioned as code. Nothing was clicked through a console. The entire stack can be destroyed and rebuilt in under 10 minutes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKFLOW                               │
│                                                                          │
│   git push origin main                                                   │
│         │                                                                │
│         ▼                                                                │
│   ┌─────────────┐                                                        │
│   │   GitHub    │  Source of truth — versioned, branch-protected        │
│   └──────┬──────┘                                                        │
│          │  triggers                                                      │
│          ▼                                                                │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                    GITHUB ACTIONS PIPELINE                        │  │
│   │                                                                   │  │
│   │  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐  │  │
│   │  │ SAST Scan   │───▶│  Docker Build    │───▶│  Trivy Image  │  │  │
│   │  │  (Bandit)   │    │  linux/amd64     │    │     Scan      │  │  │
│   │  │             │    │  git SHA tag     │    │  CRITICAL+HIGH│  │  │
│   │  └─────────────┘    └──────────────────┘    └───────┬────────┘  │  │
│   │   Blocks on HIGH         Immutable tags              │ passes    │  │
│   │   severity issues        Full traceability           ▼           │  │
│   │                                              ┌────────────────┐  │  │
│   │                                              │   ECR Push     │  │  │
│   │                                              │ git-SHA tagged │  │  │
│   │                                              └───────┬────────┘  │  │
│   │                                                      │           │  │
│   │                                              ┌───────▼────────┐  │  │
│   │                                              │  ECS Deploy    │  │  │
│   │                                              │ Rolling update │  │  │
│   │                                              │ Zero downtime  │  │  │
│   │                                              └────────────────┘  │  │
│   └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS INFRASTRUCTURE (Terraform)                   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                         VPC (10.0.0.0/16)                         │  │
│  │                                                                   │  │
│  │   Public Subnets (AZ-a, AZ-b)    Private Subnets (AZ-a, AZ-b)  │  │
│  │   ┌─────────────────────┐        ┌──────────────────────────┐   │  │
│  │   │  Application Load   │        │     ECS Fargate Tasks    │   │  │
│  │   │     Balancer        │───────▶│   (no public IP, NAT     │   │  │
│  │   │   Port 80 → 5000    │        │    gateway for egress)   │   │  │
│  │   └─────────────────────┘        └──────────────────────────┘   │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────────────┐ │
│  │     ECR      │  │  Secrets     │  │      CloudWatch               │ │
│  │  Repository  │  │  Manager     │  │  Dashboard · Alarms · Logs    │ │
│  │  Scan on push│  │  No hardcoded│  │  CPU · Memory · Task health   │ │
│  │  Mutable tags│  │  credentials │  │  Pipeline success/failure     │ │
│  └──────────────┘  └──────────────┘  └───────────────────────────────┘ │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Terraform State Management                     │  │
│  │         S3 bucket (versioned, encrypted) + DynamoDB lock         │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Security Gates

Every deployment passes through three mandatory security checkpoints before a single byte reaches production.

| Gate | Tool | What It Catches | Action on Failure |
|---|---|---|---|
| SAST | Bandit | Code-level vulnerabilities, hardcoded secrets, insecure patterns | Pipeline blocked |
| Image Scan | Trivy | OS CVEs, library CVEs, known exploits in container layers | Pipeline blocked |
| Secrets Management | AWS Secrets Manager | Eliminates hardcoded credentials from code and environment variables | N/A — enforced by design |

---

## Infrastructure Components

| Component | Service | Purpose |
|---|---|---|
| Container Registry | Amazon ECR | Private image storage with automatic vulnerability scanning |
| Container Runtime | ECS Fargate | Serverless containers — no EC2 to manage or patch |
| Load Balancer | Application Load Balancer | Traffic distribution, health checks, rolling deployments |
| Networking | VPC + Private Subnets | Containers isolated from internet; only ALB is public-facing |
| CI/CD | GitHub Actions | Source-triggered automation — SAST, build, scan, deploy |
| Secondary Pipeline | AWS CodePipeline + CodeBuild | AWS-native pipeline for enterprise governance requirements |
| Observability | CloudWatch | Metrics, alarms, log aggregation, custom dashboard |
| Alerting | SNS | Email notification on pipeline failure or service degradation |
| IaC | Terraform | All resources version-controlled, reproducible, modular |
| State Backend | S3 + DynamoDB | Remote state with distributed locking |

---

## Repository Structure

```
devsecops-aws-poc/
├── app/
│   └── app.py                    # Flask application
├── terraform/
│   ├── main.tf                   # Root module — wires all modules
│   ├── variables.tf              # All configuration inputs
│   ├── outputs.tf                # Post-apply outputs (ALB URL, ECR URI)
│   ├── providers.tf              # AWS provider + S3 backend config
│   ├── bootstrap.tf              # S3 state bucket + DynamoDB lock table
│   └── modules/
│       ├── iam/                  # Roles for ECS, CodeBuild, CodePipeline
│       ├── network/              # VPC, subnets, IGW, NAT, route tables
│       ├── ecr/                  # Container registry + lifecycle policy
│       ├── ecs/                  # Cluster, task definition, service, ALB
│       ├── pipeline/             # CodePipeline, CodeBuild, S3 artifacts
│       └── observability/        # CloudWatch dashboard, alarms, SNS
├── .github/
│   └── workflows/
│       └── devsecops-pipeline.yml  # GitHub Actions — full CICD pipeline
├── Dockerfile                    # Multi-stage, linux/amd64, non-root user
├── buildspec.yml                 # CodeBuild — SAST + build + scan + push
├── requirements.txt
├── .gitignore
└── .dockerignore
```

---

## Pipeline Flow

A push to `main` triggers the following automated sequence:

**1. SAST Security Scan**
Bandit scans all Python source files. Issues at HIGH severity block the pipeline. Medium issues are logged for review.

**2. Docker Build**
Image is built targeting `linux/amd64` explicitly — avoids architecture mismatch with ECS Fargate. Tagged with the first 8 characters of the git commit SHA for full traceability.

**3. Trivy Image Scan**
The built image is scanned against the NVD and OS vendor advisories. Any CRITICAL or HIGH severity CVE with a fixed version available blocks the pipeline. Unfixed vulnerabilities are acknowledged but do not block.

**4. ECR Push**
The scanned, verified image is pushed to ECR with the git SHA tag. ECR automatically runs its own vulnerability scan on push as a secondary check.

**5. ECS Deploy**
The current ECS task definition is downloaded, the container image URI is updated to the new image, a new task definition revision is registered, and the ECS service is updated. ECS performs a rolling deployment — the new task starts and passes health checks before the old task is drained and stopped. Zero downtime.

---

## Observability

The CloudWatch dashboard provides a single-pane view of system health:

- ECS CPU and memory utilisation (per service)
- Running task count with breach alarm at zero
- CodePipeline execution success and failure rates
- Alarm status panel — all four alarms in one view

Alarms configured:

| Alarm | Threshold | Action |
|---|---|---|
| CPU High | > 80% for 2 consecutive periods | SNS email |
| Memory High | > 80% for 2 consecutive periods | SNS email |
| No Running Tasks | < 1 task | SNS email (treat missing as breach) |
| Pipeline Failed | Any failure | SNS email |

---

## Deploying From Scratch

**Prerequisites:** AWS CLI configured, Terraform >= 1.7.0, Docker Desktop running.

```bash
# Clone the repository
git clone git@github.com:MurLeeDas/devsecops-aws-poc.git
cd devsecops-aws-poc/terraform

# Step 1: Bootstrap state backend (run once)
# Comment out the backend "s3" block in providers.tf first
terraform init -reconfigure
terraform apply \
  -target=aws_s3_bucket.tfstate \
  -target=aws_s3_bucket_versioning.tfstate \
  -target=aws_s3_bucket_server_side_encryption_configuration.tfstate \
  -target=aws_s3_bucket_public_access_block.tfstate \
  -target=aws_dynamodb_table.tflock \
  -auto-approve

# Step 2: Migrate state to S3
# Uncomment the backend "s3" block in providers.tf
terraform init -migrate-state

# Step 3: Deploy all infrastructure
terraform plan
terraform apply -auto-approve

# Step 4: Authorise GitHub connection
# AWS Console → Developer Tools → Connections → Update pending connection

# Step 5: Add GitHub Actions secrets
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ECR_REGISTRY
```

After the GitHub connection is authorised, push any commit to `main` to trigger the full pipeline.

---

## GitHub Actions Secrets Required

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `ECR_REGISTRY` | `<account-id>.dkr.ecr.ap-south-1.amazonaws.com` |

---

## Design Decisions

**Why Fargate over EC2?** No server management, no patching cycle, pay only for task runtime. For a team focused on application delivery, operational overhead of EC2 management is unjustifiable.

**Why private subnets for ECS?** Defence in depth. Even if an attacker finds a vulnerability in the application, there is no direct network path from the internet to the container. Traffic flows: Internet → ALB (public subnet) → ECS task (private subnet, via security group restriction).

**Why git SHA image tags?** Every running container in production is traceable to the exact commit that built it. If a production issue appears, the debugging path is: check task definition → get image tag → match to git commit → view the diff. No ambiguity.

**Why Terraform modules?** This codebase can deploy the same architecture for a different client by changing five variable values. Each module is independently testable and reusable.

---

## Live Demo Endpoints

```
GET /              → Service info, version, environment, timestamp
GET /health        → Health check (used by ALB target group)
GET /pipeline-info → Pipeline architecture summary
```

---

## Consultant Contact

**Murali Doss**  
DevSecOps & Cloud Consultant  
[linkedin.com/in/dossops](https://www.linkedin.com/in/dossops/)

Specialised in DevSecOps transformation for telecom and fintech organisations.  
Previous engagements: Grameenphone (Bangladesh), Odido/T-Mobile (Netherlands).

Available for pipeline audits, DevSecOps maturity assessments, and implementation engagements.