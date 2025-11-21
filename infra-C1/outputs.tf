output "ssh_private_key" {
  description = "Private key for SSH access"
  value       = module.infra.ssh_private_key
  sensitive   = true
}

output "bastion_public_ip" {
  description = "Public IP of the bastion instance"
  value       = module.infra.bastion_public_ip
}