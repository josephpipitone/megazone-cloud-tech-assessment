terraform {
  backend "s3" {
    bucket       = "mzc-assessment-prod-terraform-state"
    key          = "network/vpc/mzc-infra-prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    profile      = "mzc-infra-prod"
    use_lockfile = true
  }
}