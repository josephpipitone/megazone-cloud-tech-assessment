variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "mzcinfra-useast1-production"
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for ALB"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "mzcinfra"
}

variable "ssh_keypair_name" {
  description = "Name of the SSH keypair"
  type        = string
  default     = "mzc-ssh-keypair"
}

variable "db_engine" {
  description = "Database engine type"
  type        = string
  default     = "postgres"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
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