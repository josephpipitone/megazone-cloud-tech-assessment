terraform {
  backend "s3" {
    bucket       = "mzc-assessment-prod-terraform-state"
    key          = "application/mzc-app-prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    profile      = "mzc-infra-prod"
    use_lockfile = true
  }
}