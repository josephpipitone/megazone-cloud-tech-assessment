vpc_name           = "mzcinfra-useast1-prod"
vpc_cidr           = "10.0.0.0/20"
azs                = ["us-east-1a", "us-east-1b"]
region             = "us-east-1"
bastion_allowed_ip = "74.44.134.129/32"
create_bastion     = true
environment        = "non-production"
name_prefix        = "mzcinfra"