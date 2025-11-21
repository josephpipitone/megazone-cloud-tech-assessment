module "networking" {
  source             = "../modules/networking"
  vpc_name           = "${var.name_prefix}-useast1-${var.environment == "production" ? "prod" : "nonprod"}"
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  region             = var.region
  bastion_allowed_ip = var.bastion_allowed_ip
  create_bastion     = var.create_bastion
  environment        = var.environment
  name_prefix        = var.name_prefix
}