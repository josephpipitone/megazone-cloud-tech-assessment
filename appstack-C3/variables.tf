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