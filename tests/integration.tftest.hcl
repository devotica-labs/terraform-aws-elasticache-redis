# Integration tests — apply + assert + destroy.
# Requires real AWS credentials AND pre-existing private subnets in the VPC.
# Triggered via workflow_dispatch on integration.yml. Provisioning a
# replication group takes several minutes, so keep this lean.

provider "aws" {
  region = "ap-south-1"
}

variables {
  namespace                  = "dvtca"
  stage                      = "integ"
  name                       = "redis"
  vpc_id                     = ""
  subnet_ids                 = []
  allowed_security_group_ids = []

  node_type    = "cache.t4g.micro"
  cluster_size = 2

  tags = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_elasticache_replication_group.this[0].arn != ""
    error_message = "Replication group must be created."
  }
  assert {
    condition     = aws_elasticache_replication_group.this[0].at_rest_encryption_enabled == true
    error_message = "At-rest encryption must be on."
  }
  assert {
    condition     = aws_elasticache_replication_group.this[0].transit_encryption_enabled == true
    error_message = "In-transit encryption must be on."
  }
  assert {
    condition     = aws_elasticache_replication_group.this[0].automatic_failover_enabled == true
    error_message = "Automatic failover must be on."
  }
}
