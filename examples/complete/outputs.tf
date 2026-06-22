output "replication_group_id" {
  description = "Replication group ID."
  value       = module.redis.replication_group_id
}

output "endpoint_address" {
  description = "Primary endpoint apps connect to (TLS)."
  value       = module.redis.endpoint_address
}

output "reader_endpoint_address" {
  description = "Reader endpoint for read replicas."
  value       = module.redis.reader_endpoint_address
}

output "arn" {
  description = "Replication group ARN."
  value       = module.redis.arn
}

output "security_group_id" {
  description = "Security group fronting the cache."
  value       = module.redis.security_group_id
}

output "member_clusters" {
  description = "All node identifiers."
  value       = module.redis.member_clusters
}
