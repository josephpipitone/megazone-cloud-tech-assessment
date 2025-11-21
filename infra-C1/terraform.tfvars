vpc_name              = "mzcinfra-useast1-prod"
vpc_cidr              = "10.0.0.0/20"
azs                   = ["us-east-1a", "us-east-1b"]
region                = "us-east-1"
profile               = "mzc-infra-prod"
bastion_allowed_ip    = "74.44.134.129/32"
bastion_instance_type = "t3.micro"
create_bastion        = true
environment           = "non-production"
owner                 = "joe@tslamars.com"
name_prefix           = "mzcinfra"
subnet_config = [
  {
    name     = "public-a"
    new_bits = 8
  },
  {
    name     = "public-b"
    new_bits = 8
  },
  {
    name     = "private-app-a"
    new_bits = 7
  },
  {
    name     = "private-app-b"
    new_bits = 7
  },
  {
    name     = "private-database-a"
    new_bits = 7
  },
  {
    name     = "private-database-b"
    new_bits = 7
  },
  {
    name     = null
    new_bits = 7
  },
  {
    name     = null
    new_bits = 7
  }
]