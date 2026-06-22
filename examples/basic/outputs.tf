output "endpoint_address" {
  description = "Primary endpoint apps connect to."
  value       = module.redis.endpoint_address
}

output "port" {
  description = "Redis port."
  value       = module.redis.port
}

output "security_group_id" {
  description = "Security group fronting the cache."
  value       = module.redis.security_group_id
}
