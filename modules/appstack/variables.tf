variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for ALB"
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "IDs of app subnets"
  type        = list(string)
}

variable "database_subnet_ids" {
  description = "IDs of database subnets"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID of ALB security group"
  type        = string
}

variable "app_sg_id" {
  description = "ID of app security group"
  type        = string
}

variable "database_sg_id" {
  description = "ID of database security group"
  type        = string
}


variable "db_secret_name" {
  description = "Name of the DB password secret"
  type        = string
}

variable "db_username" {
  description = "DB username"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "DB engine version"
  type        = string
  default     = "16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Min size of ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Max size of ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired capacity of ASG"
  type        = number
  default     = 2
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for ALB"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["production", "non-production"], var.environment)
    error_message = "Environment must be 'production' or 'non-production'."
  }
}

variable "ami_name_filter" {
  description = "AMI name filter pattern"
  type        = string
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "user_data_script" {
  description = "Base64 encoded user data script"
  type        = string
}

variable "ssh_keypair_name" {
  description = "Name of the SSH keypair"
  type        = string
  default     = "mzc-ssh-keypair"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "mzc"
}
