output "replication_group_id" {
  description = "Replication group ID."
  value       = one(aws_elasticache_replication_group.this[*].id)
}

output "arn" {
  description = "Replication group ARN."
  value       = one(aws_elasticache_replication_group.this[*].arn)
}

output "engine_version_actual" {
  description = "The running engine version."
  value       = one(aws_elasticache_replication_group.this[*].engine_version_actual)
}

output "endpoint_address" {
  description = "Primary endpoint (replica mode) or configuration endpoint (cluster mode) — the address apps connect to."
  value       = var.cluster_mode_enabled ? one(aws_elasticache_replication_group.this[*].configuration_endpoint_address) : one(aws_elasticache_replication_group.this[*].primary_endpoint_address)
}

output "primary_endpoint_address" {
  description = "Primary node endpoint address (replica mode)."
  value       = one(aws_elasticache_replication_group.this[*].primary_endpoint_address)
}

output "reader_endpoint_address" {
  description = "Reader endpoint address (replica mode)."
  value       = one(aws_elasticache_replication_group.this[*].reader_endpoint_address)
}

output "configuration_endpoint_address" {
  description = "Configuration endpoint address (cluster mode)."
  value       = one(aws_elasticache_replication_group.this[*].configuration_endpoint_address)
}

output "port" {
  description = "Port the cache accepts connections on."
  value       = var.port
}

output "member_clusters" {
  description = "Identifiers of all nodes in the replication group."
  value       = one(aws_elasticache_replication_group.this[*].member_clusters)
}

output "security_group_id" {
  description = "ID of the security group created for the cache (null if create_security_group = false)."
  value       = one(aws_security_group.this[*].id)
}

output "subnet_group_name" {
  description = "Name of the created ElastiCache subnet group."
  value       = one(aws_elasticache_subnet_group.this[*].name)
}

output "parameter_group_name" {
  description = "Name of the parameter group in effect."
  value       = local.parameter_group_name
}

output "auth_token_set" {
  description = "Whether an AUTH token is configured (the token itself is never output)."
  value       = nonsensitive(var.auth_token != null)
}
