# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------
variable "vpc_id" {
  type        = string
  description = "VPC the Redis replication group and its security group live in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the ElastiCache subnet group (one per AZ you want a node in)."
}

variable "port" {
  type        = number
  description = "Port the cache nodes accept connections on."
  default     = 6379
}

variable "availability_zones" {
  type        = list(string)
  description = "Preferred AZs for the cache clusters. Empty lets AWS choose."
  default     = []
}

# ---------------------------------------------------------------------------
# Engine + sizing
# ---------------------------------------------------------------------------
variable "engine" {
  type        = string
  description = "Cache engine: `redis` or `valkey`."
  default     = "redis"
}

variable "engine_version" {
  type        = string
  description = "Engine version. Must be 6+ for transit encryption and auto minor upgrades."
  default     = "7.1"
}

variable "family" {
  type        = string
  description = "Parameter group family (e.g. `redis7`)."
  default     = "redis7"
}

variable "node_type" {
  type        = string
  description = "Node instance class. Defaults to a Graviton (t4g) class, which supports at-rest/in-transit encryption and failover (unlike t1/t2)."
  # Devotica fintech default: Graviton + a class that supports encryption + failover.
  default = "cache.t4g.micro"
}

variable "cluster_size" {
  type        = number
  description = "Number of cache nodes (1 primary + N replicas) when `cluster_mode_enabled = false`. Devotica defaults to 2 so automatic failover + Multi-AZ are usable."
  # Devotica fintech default: the AWS default is 1 (no replica → no failover).
  default = 2
}

variable "cluster_mode_enabled" {
  type        = bool
  description = "Enable Redis Cluster mode (sharding across node groups)."
  default     = false
}

variable "num_node_groups" {
  type        = number
  description = "Number of shards (node groups) when `cluster_mode_enabled = true`."
  default     = 1
}

variable "replicas_per_node_group" {
  type        = number
  description = "Replicas per shard when `cluster_mode_enabled = true` (0-5)."
  default     = 1
}

# ---------------------------------------------------------------------------
# High availability (Devotica fintech defaults)
# ---------------------------------------------------------------------------
variable "automatic_failover_enabled" {
  type        = bool
  description = "Automatically fail over to a replica if the primary fails. Requires at least one replica (cluster_size >= 2). Forced on in cluster mode."
  # Devotica fintech default: the AWS default is false.
  default = true
}

variable "multi_az_enabled" {
  type        = bool
  description = "Spread nodes across AZs. Requires automatic failover."
  # Devotica fintech default: the AWS default is false.
  default = true
}

# ---------------------------------------------------------------------------
# Encryption + auth (Devotica fintech defaults)
# ---------------------------------------------------------------------------
variable "at_rest_encryption_enabled" {
  type        = bool
  description = "Encrypt data at rest. Uses an AWS-managed key unless `kms_key_id` is supplied."
  # Devotica fintech default: the AWS default is false.
  default = true
}

variable "kms_key_id" {
  type        = string
  description = "Customer-managed KMS key ARN for at-rest encryption (e.g. a terraform-aws-kms output). Null uses the AWS-managed key. Requires `at_rest_encryption_enabled = true`."
  default     = null
}

variable "transit_encryption_enabled" {
  type        = bool
  description = "Encrypt data in transit (TLS). Clients must connect over TLS when enabled."
  default     = true
}

variable "transit_encryption_mode" {
  type        = string
  description = "Transit-encryption migration mode: `preferred` or `required`. Set `preferred` first when enabling on an existing group, then `required`."
  default     = null
}

variable "auth_token" {
  type        = string
  description = "Redis AUTH token (16-128 chars). Requires transit encryption. Prefer RBAC via `user_group_ids` for new deployments."
  default     = null
  sensitive   = true

  validation {
    condition     = var.auth_token == null || can(regex("^.{16,128}$", coalesce(var.auth_token, "x")))
    error_message = "auth_token must be between 16 and 128 characters."
  }
}

variable "auth_token_update_strategy" {
  type        = string
  description = "How to apply auth_token changes: `SET`, `ROTATE`, or `DELETE`."
  default     = "ROTATE"

  validation {
    condition     = contains(["set", "rotate", "delete"], lower(var.auth_token_update_strategy))
    error_message = "Valid values for auth_token_update_strategy are SET, ROTATE, and DELETE."
  }
}

variable "user_group_ids" {
  type        = list(string)
  description = "RBAC user group IDs to associate with the replication group (the modern alternative to auth_token)."
  default     = null
}

# ---------------------------------------------------------------------------
# Maintenance + backup
# ---------------------------------------------------------------------------
variable "maintenance_window" {
  type        = string
  description = "Weekly maintenance window (UTC)."
  default     = "wed:03:00-wed:04:00"
}

variable "snapshot_window" {
  type        = string
  description = "Daily window (UTC) for automated snapshots."
  default     = "06:30-07:30"
}

variable "snapshot_retention_limit" {
  type        = number
  description = "Days to retain automated snapshots. Devotica defaults to 7; 0 disables backups."
  # Devotica fintech default: the AWS default is 0 (no backups).
  default = 7
}

variable "final_snapshot_identifier" {
  type        = string
  description = "Name of the final snapshot taken on destroy. Null skips the final snapshot."
  default     = null
}

variable "apply_immediately" {
  type        = bool
  description = "Apply modifications immediately instead of during the maintenance window."
  # Devotica fintech default: the AWS default is true; we default to false to avoid surprise disruption.
  default = false
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Apply minor engine upgrades automatically during the maintenance window (engine 6+)."
  # Devotica fintech default: pick up patch-level fixes automatically.
  default = true
}

variable "data_tiering_enabled" {
  type        = bool
  description = "Enable data tiering (only supported on r6gd node types)."
  default     = false
}

# ---------------------------------------------------------------------------
# Parameter group
# ---------------------------------------------------------------------------
variable "create_parameter_group" {
  type        = bool
  description = "Create a dedicated parameter group. Set false to use `parameter_group_name`."
  default     = true
}

variable "parameter_group_name" {
  type        = string
  description = "Existing parameter group name to use when `create_parameter_group = false`."
  default     = null
}

variable "parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Redis parameters to set on the created parameter group."
  default     = []
}

# ---------------------------------------------------------------------------
# Networking / security group
# ---------------------------------------------------------------------------
variable "create_security_group" {
  type        = bool
  description = "Create a security group for the cache. If false, supply access via `associated_security_group_ids`."
  default     = true
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Source security group IDs allowed to reach Redis on `port` (e.g. your app/ECS/EKS service SGs)."
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach Redis on `port`. Prefer security-group sources over CIDRs."
  default     = []
}

variable "associated_security_group_ids" {
  type        = list(string)
  description = "Existing security group IDs to attach to the cache in addition to (or instead of) the created one."
  default     = []
}

# ---------------------------------------------------------------------------
# Logging + alarms
# ---------------------------------------------------------------------------
variable "log_delivery_configuration" {
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  description = "Stream slow-log / engine-log to CloudWatch Logs or Kinesis Firehose (max 2 entries)."
  default     = []
}

variable "cloudwatch_metric_alarms_enabled" {
  type        = bool
  description = "Create CPU + freeable-memory CloudWatch alarms per node."
  default     = false
}

variable "alarm_cpu_threshold_percent" {
  type        = number
  description = "CPU utilization alarm threshold (percent)."
  default     = 75
}

variable "alarm_memory_threshold_bytes" {
  type        = number
  description = "Freeable-memory alarm threshold (bytes)."
  default     = 10000000
}

variable "alarm_actions" {
  type        = list(string)
  description = "ARNs notified when an alarm fires (e.g. an SNS topic)."
  default     = []
}

variable "ok_actions" {
  type        = list(string)
  description = "ARNs notified when an alarm clears."
  default     = []
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
variable "description" {
  type        = string
  description = "Description for the replication group. Defaults to the composed name."
  default     = null
}

variable "notification_topic_arn" {
  type        = string
  description = "SNS topic ARN for ElastiCache event notifications."
  default     = null
}

variable "replication_group_id" {
  type        = string
  description = "Override the replication group ID. Defaults to the composed name (<= 40 chars, must start with a letter)."
  default     = null
}
