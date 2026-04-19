module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "network" {
  source       = "./modules/network"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

module "ecs" {
  source                = "./modules/ecs"
  project_name          = var.project_name
  environment           = var.environment
  ecr_repo_url          = module.ecr.repository_url
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  public_subnet_ids     = module.network.public_subnet_ids
  ecs_task_role_arn     = module.iam.ecs_task_role_arn
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  container_port        = var.container_port
  aws_region            = var.aws_region
}

module "pipeline" {
  source                  = "./modules/pipeline"
  project_name            = var.project_name
  environment             = var.environment
  github_owner            = var.github_owner
  github_repo             = var.github_repo
  github_branch           = var.github_branch
  ecr_repo_url            = module.ecr.repository_url
  ecr_repo_name           = module.ecr.repository_name
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  codebuild_role_arn      = module.iam.codebuild_role_arn
  codepipeline_role_arn   = module.iam.codepipeline_role_arn
  aws_region              = var.aws_region
}

module "observability" {
  source           = "./modules/observability"
  project_name     = var.project_name
  environment      = var.environment
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name
  pipeline_name    = module.pipeline.pipeline_name
  alert_email      = var.alert_email
}
