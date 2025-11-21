output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of private app subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_database_subnet_ids" {
  description = "IDs of private database subnets"
  value       = aws_subnet.private_database[*].id
}

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gw_id" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "bastion_sg_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "app_sg_id" {
  description = "ID of the app security group"
  value       = aws_security_group.app.id
}

output "data_sg_id" {
  description = "ID of the data security group"
  value       = aws_security_group.data.id
}

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "bastion_instance_id" {
  description = "ID of the bastion instance"
  value       = var.create_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP of the bastion instance"
  value       = var.create_bastion ? aws_instance.bastion[0].public_ip : null
}

output "ssh_private_key" {
  description = "Private key for SSH access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "subnet_addrs_keys" {
  description = "Keys of the subnet address blocks"
  value       = keys(module.subnet_addrs.network_cidr_blocks)
}