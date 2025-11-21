module "infra" {
  source                = "../modules/infra"
  vpc_name              = "${var.name_prefix}-useast1-${var.environment == "production" ? "prod" : "nonprod"}"
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  region                = var.region
  bastion_allowed_ip    = var.bastion_allowed_ip
  create_bastion        = var.create_bastion
  bastion_instance_type = var.bastion_instance_type
  environment           = var.environment
  name_prefix           = var.name_prefix
  subnet_config         = var.subnet_config
}