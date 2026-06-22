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

  # Name composes to: dvtca-sandbox-sessions
  namespace = "dvtca"
  stage     = "sandbox"
  name      = "sessions"

  vpc_id     = "vpc-00000000000000000"
  subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]

  # Allow the app tier in on 6379.
  allowed_security_group_ids = ["sg-0appapp00000000000"]

  # Fintech defaults already cover the rest: at-rest + in-transit encryption,
  # 2 nodes with automatic failover + Multi-AZ, 7-day snapshot retention,
  # Graviton node type, apply_immediately = false.

  tags = {
    Environment = "sandbox"
    Project     = "terraform-aws-elasticache-redis"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-elasticache-redis"
  }
}
