output "ssh_private_key" {
  description = "Private key for SSH access"
  value       = module.networking.ssh_private_key
  sensitive   = true
}

output "bastion_public_ip" {
  description = "Public IP of the bastion instance"
  value       = module.networking.bastion_public_ip
}