output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_secret_arn" {
  description = "ARN of the DB secret"
  value       = aws_secretsmanager_secret.main.arn
}

output "db_connection_string_secret_arn" {
  description = "ARN of the DB connection string secret"
  value       = aws_secretsmanager_secret.connection_string.arn
}