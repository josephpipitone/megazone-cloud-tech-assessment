variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "bastion_allowed_ip" {
  description = "IP address allowed to SSH to bastion"
  type        = string
  default     = "74.44.134.129/32"
}

variable "create_bastion" {
  description = "Whether to create bastion host"
  type        = bool
  default     = true
}

variable "bastion_key_name" {
  description = "SSH key pair name for bastion"
  type        = string
  default     = null
}

variable "ssh_keypair_name" {
  description = "Name of the SSH keypair"
  type        = string
  default     = "mzc-ssh-keypair"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "mzcinfra"
}

variable "common_tags" {
  type        = map(string)
  description = "Map of tags to add to all resources"
  default = {
    "Owner"     = "joseph.pipitone@gmail.com"
    "ManagedBy" = "terraform"
  }
}