# Contract tests — naming + key inputs stay stable across minor/patch versions.

mock_provider "aws" {}

variables {
  namespace                  = "dvtca"
  stage                      = "test"
  name                       = "contract"
  vpc_id                     = "vpc-00000000000000000"
  subnet_ids                 = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  allowed_security_group_ids = ["sg-00000000000000000"]
}

run "replication_group_id_from_name" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].replication_group_id == "dvtca-test-contract"
    error_message = "Replication group ID must compose namespace-stage-name."
  }
}

run "subnet_group_named_from_id" {
  command = plan
  assert {
    condition     = aws_elasticache_subnet_group.this[0].name == "dvtca-test-contract"
    error_message = "Subnet group name must equal the composed id."
  }
}

run "parameter_group_named_from_id_and_family" {
  command = plan
  assert {
    condition     = aws_elasticache_parameter_group.this[0].name == "dvtca-test-contract-redis7"
    error_message = "Parameter group name must be <id>-<safe-family>."
  }
}

run "default_engine_and_port" {
  command = plan
  assert {
    condition     = aws_elasticache_replication_group.this[0].engine == "redis"
    error_message = "Default engine must be redis."
  }
  assert {
    condition     = aws_elasticache_replication_group.this[0].port == 6379
    error_message = "Default port must be 6379."
  }
}

run "default_family" {
  command = plan
  assert {
    condition     = aws_elasticache_parameter_group.this[0].family == "redis7"
    error_message = "Default parameter group family must be redis7."
  }
}
