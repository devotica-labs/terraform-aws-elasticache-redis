# Plan-only unit tests — no AWS credentials required. The module has no data
# sources, so an empty mock provider suffices.

mock_provider "aws" {}

variables {
  namespace                  = "dvtca"
  stage                      = "test"
  name                       = "unit"
  vpc_id                     = "vpc-00000000000000000"
  subnet_ids                 = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  allowed_security_group_ids = ["sg-00000000000000000"]
}

run "replication_group_created" {
  command = plan
  assert {
    condition     = length(aws_elasticache_replication_group.this) == 1
    error_message = "Exactly one replication group must be planned."
  }
}

run "encryption_on_by_default" {
  command = plan
  assert {
    condition     = tostring(aws_elasticache_replication_group.this[0].at_rest_encryption_enabled) == "true"
    error_message = "At-rest encryption must be on by default."
  }
  assert {
    condition     = tostring(aws_elasticache_replication_group.this[0].transit_encryption_enabled) == "true"
    error_message = "In-transit encryption must be on by default."
  }
}

run "ha_on_by_default" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].automatic_failover_enabled == true
    error_message = "Automatic failover must be on by default."
  }
  assert {
    condition     = aws_elasticache_replication_group.this[0].multi_az_enabled == true
    error_message = "Multi-AZ must be on by default."
  }
}

run "two_nodes_default" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].num_cache_clusters == 2
    error_message = "Default cluster_size must be 2 (so failover is usable)."
  }
}

run "graviton_node_type_default" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].node_type == "cache.t4g.micro"
    error_message = "Default node type must be the Graviton t4g class."
  }
}

run "snapshot_retention_default_7" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].snapshot_retention_limit == 7
    error_message = "Default snapshot retention must be 7 days."
  }
}

run "apply_immediately_off_by_default" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].apply_immediately == false
    error_message = "apply_immediately must default to false."
  }
}

run "security_group_created_with_one_ingress" {
  command = plan
  assert {
    condition     = length(aws_security_group.this) == 1
    error_message = "A security group must be created by default."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_sg) == 1
    error_message = "One ingress rule per allowed source SG expected."
  }
}

run "byo_security_group_skips_creation" {
  command = plan
  variables {
    create_security_group         = false
    associated_security_group_ids = ["sg-0byob0byob0byob00"]
  }
  assert {
    condition     = length(aws_security_group.this) == 0
    error_message = "No security group should be created when create_security_group = false."
  }
}

run "kms_key_passthrough_when_set" {
  command = plan
  variables {
    kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/abc"
  }
  assert {
    condition     = aws_elasticache_replication_group.this[0].kms_key_id == "arn:aws:kms:ap-south-1:111122223333:key/abc"
    error_message = "The supplied KMS key must be passed through for at-rest encryption."
  }
}

run "subnet_and_parameter_group_created" {
  command = plan
  assert {
    condition     = length(aws_elasticache_subnet_group.this) == 1
    error_message = "A subnet group must be created."
  }
  assert {
    condition     = length(aws_elasticache_parameter_group.this) == 1
    error_message = "A parameter group must be created by default."
  }
}
