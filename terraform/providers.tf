terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devsecops-poc-tfstate"
    key            = "devsecops/poc/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "devsecops-poc-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "DevSecOps-POC"
      ManagedBy   = "Terraform"
      Consultant  = "Murali Doss"
      Environment = var.environment
    }
  }
}
