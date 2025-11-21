data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-public-*-${var.environment == "production" ? "prod" : "nonprod"}"]
  }
}

data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-private-app-*-${var.environment == "production" ? "prod" : "nonprod"}"]
  }
}

data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-private-database-*-${var.environment == "production" ? "prod" : "nonprod"}"]
  }
}

data "aws_security_groups" "alb" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-alb-sg-${var.environment == "production" ? "prod" : "nonprod"}"]
  }
}

data "aws_security_groups" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-app-sg-${var.environment == "production" ? "prod" : "nonprod"}"]
  }
}

data "aws_security_groups" "database" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-database-sg-${var.environment == "production" ? "prod" : "nonprod"}"]
  }
}

module "appstack" {
  source                 = "../modules/appstack"
  environment            = var.environment
  vpc_name               = var.vpc_name
  public_subnet_ids      = data.aws_subnets.public.ids
  app_subnet_ids         = data.aws_subnets.app.ids
  database_subnet_ids    = data.aws_subnets.database.ids
  alb_sg_id              = data.aws_security_groups.alb.ids[0]
  app_sg_id              = data.aws_security_groups.app.ids[0]
  database_sg_id         = data.aws_security_groups.database.ids[0]
  certificate_arn        = var.certificate_arn
  db_secret_name         = "mzc-app-${var.environment == "production" ? "prod" : "nonprod"}-db-password6"
  ssh_keypair_name       = var.ssh_keypair_name
  user_data_script       = filebase64("user-data.sh")
  db_engine              = var.db_engine
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_multi_az            = var.db_multi_az
  db_skip_final_snapshot = var.db_skip_final_snapshot
  instance_type          = var.instance_type
  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.desired_capacity
  name_prefix            = var.name_prefix
}