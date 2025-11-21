terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "mzc-infra-prod"
  default_tags {
    tags = { 
      Owner = var.owner
      ManagedBy = "Terraform"
      Environment = var.environment 
    }
  }
}