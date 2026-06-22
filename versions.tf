terraform {
  # >= 1.5.0 for `check` blocks (used in main.tf for the HA guardrails).
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.73.0"
    }
  }
}
