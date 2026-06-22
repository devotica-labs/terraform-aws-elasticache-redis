# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/elasticache-redis/aws"
#   version = "~> 0.1"

module "redis" {
  source = "../.."

  # Name composes to: dvtca-aps1-prod-payments
  namespace   = "dvtca"
  environment = "aps1"
  stage       = "prod"
  name        = "payments"

  vpc_id = "vpc-00000000000000000"
  subnet_ids = [
    "subnet-aaaaaaaaaaaaaaaaa",
    "subnet-bbbbbbbbbbbbbbbbb",
    "subnet-ccccccccccccccccc",
  ]

  # 3 nodes (1 primary + 2 replicas) across AZs with automatic failover.
  node_type    = "cache.r7g.large"
  cluster_size = 3

  # Encrypt at rest with a workload KMS key (a terraform-aws-kms output).
  at_rest_encryption_enabled = true
  kms_key_id                 = "arn:aws:kms:ap-south-1:111122223333:key/00000000-0000-0000-0000-000000000000"

  # TLS in transit + RBAC (preferred over a shared auth token).
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  user_group_ids             = ["dvtca-prod-payments-app"]

  # Ingress only from the application security group.
  allowed_security_group_ids = ["sg-0appapp00000000000"]

  # Tune the engine.
  parameters = [
    { name = "maxmemory-policy", value = "allkeys-lru" },
  ]

  # Ship the slow log to CloudWatch.
  log_delivery_configuration = [
    {
      destination      = "/aws/elasticache/dvtca-aps1-prod-payments/slow-log"
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "slow-log"
    },
  ]

  # Backups + observability.
  snapshot_retention_limit         = 14
  final_snapshot_identifier        = "dvtca-prod-payments-final"
  cloudwatch_metric_alarms_enabled = true

  tags = {
    Environment = "production"
    Project     = "payments"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-elasticache-redis"
  }
}
