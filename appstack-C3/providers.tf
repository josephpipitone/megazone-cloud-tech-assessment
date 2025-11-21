terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "mzc-infra-prod"
  default_tags {
    tags = {
      Owner     = "joseph.pipitone@gmail.com"
      ManagedBy = "Terraform"
    }
  }
}