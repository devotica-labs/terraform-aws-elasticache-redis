locals {
  replication_group_id = coalesce(var.replication_group_id, local.id)
  create_sg            = local.enabled && var.create_security_group

  # Security groups attached to the cache: the created one (if any) + any BYO.
  attached_sg_ids = concat(
    local.create_sg ? [aws_security_group.this[0].id] : [],
    var.associated_security_group_ids,
  )

  # Cluster mode (sharded) vs. replica mode (single shard, N replicas).
  num_cache_clusters      = var.cluster_mode_enabled ? null : var.cluster_size
  num_node_groups         = var.cluster_mode_enabled ? var.num_node_groups : null
  replicas_per_node_group = var.cluster_mode_enabled ? var.replicas_per_node_group : null
  # Failover is forced on in cluster mode; otherwise honour the variable.
  automatic_failover = var.cluster_mode_enabled ? true : var.automatic_failover_enabled
  # preferred_cache_cluster_azs only applies to replica mode.
  preferred_azs = (var.cluster_mode_enabled || length(var.availability_zones) == 0) ? null : var.availability_zones

  safe_family          = replace(var.family, ".", "-")
  parameter_group_name = var.create_parameter_group ? one(aws_elasticache_parameter_group.this[*].name) : var.parameter_group_name

  # Number of nodes — computed from config (known at plan) so the alarm count
  # does not depend on apply-time values.
  member_clusters_count = var.cluster_mode_enabled ? var.num_node_groups * (var.replicas_per_node_group + 1) : var.cluster_size
  member_clusters       = local.enabled ? tolist(one(aws_elasticache_replication_group.this[*].member_clusters)) : []
}

# ---------------------------------------------------------------------------
# Fintech guardrails (advisory checks — surface misconfig early in plan).
# ---------------------------------------------------------------------------
check "failover_requires_replica" {
  assert {
    condition     = !var.automatic_failover_enabled || var.cluster_mode_enabled || var.cluster_size >= 2
    error_message = "automatic_failover_enabled needs at least one replica — set cluster_size >= 2 (or enable cluster mode)."
  }
}

check "multiaz_requires_failover" {
  assert {
    condition     = !var.multi_az_enabled || var.automatic_failover_enabled || var.cluster_mode_enabled
    error_message = "multi_az_enabled requires automatic_failover_enabled."
  }
}

check "auth_token_requires_transit" {
  assert {
    condition     = var.auth_token == null || var.transit_encryption_enabled
    error_message = "auth_token requires transit_encryption_enabled = true."
  }
}

# ---------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  count       = local.create_sg ? 1 : 0
  name        = "${local.id}-redis"
  description = "Redis access for ${local.id}"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${local.id}-redis" })
}

resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each = local.create_sg ? toset(var.allowed_security_group_ids) : toset([])

  security_group_id            = aws_security_group.this[0].id
  referenced_security_group_id = each.value
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  description                  = "Redis from ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "from_cidr" {
  for_each = local.create_sg ? toset(var.allowed_cidr_blocks) : toset([])

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = each.value
  from_port         = var.port
  to_port           = var.port
  ip_protocol       = "tcp"
  description       = "Redis from ${each.value}"
}

# trivy:ignore:AVD-AWS-0104 — unrestricted egress is intentional: the cache
# needs outbound for replication, KMS, and CloudWatch. Inbound is restricted
# to the configured sources only.
resource "aws_vpc_security_group_egress_rule" "all" {
  count = local.create_sg ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

# ---------------------------------------------------------------------------
# Subnet group + parameter group
# ---------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "this" {
  count = local.enabled ? 1 : 0

  name        = local.id
  description = "Subnet group for ${local.id}"
  subnet_ids  = var.subnet_ids
  tags        = local.tags
}

resource "aws_elasticache_parameter_group" "this" {
  count = local.enabled && var.create_parameter_group ? 1 : 0

  name        = "${local.id}-${local.safe_family}"
  description = "Parameter group for ${local.id}"
  family      = var.family

  dynamic "parameter" {
    for_each = var.cluster_mode_enabled ? concat([{ name = "cluster-enabled", value = "yes" }], var.parameters) : var.parameters
    content {
      name  = parameter.value.name
      value = tostring(parameter.value.value)
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [description]
  }
}

# ---------------------------------------------------------------------------
# Replication group (the Redis cluster)
# ---------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "this" {
  count = local.enabled ? 1 : 0

  replication_group_id = local.replication_group_id
  description          = coalesce(var.description, local.id)

  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  num_cache_clusters          = local.num_cache_clusters
  num_node_groups             = local.num_node_groups
  replicas_per_node_group     = local.replicas_per_node_group
  automatic_failover_enabled  = local.automatic_failover
  multi_az_enabled            = var.multi_az_enabled
  preferred_cache_cluster_azs = local.preferred_azs

  subnet_group_name    = one(aws_elasticache_subnet_group.this[*].name)
  security_group_ids   = local.attached_sg_ids
  parameter_group_name = local.parameter_group_name

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  kms_key_id                 = var.at_rest_encryption_enabled ? var.kms_key_id : null
  transit_encryption_enabled = var.transit_encryption_enabled
  transit_encryption_mode    = var.transit_encryption_enabled ? var.transit_encryption_mode : null
  auth_token                 = var.transit_encryption_enabled ? var.auth_token : null
  auth_token_update_strategy = var.auth_token != null ? var.auth_token_update_strategy : null
  user_group_ids             = var.user_group_ids

  maintenance_window         = var.maintenance_window
  snapshot_window            = var.snapshot_window
  snapshot_retention_limit   = var.snapshot_retention_limit
  final_snapshot_identifier  = var.final_snapshot_identifier
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  data_tiering_enabled       = var.data_tiering_enabled
  notification_topic_arn     = var.notification_topic_arn

  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [security_group_names]
  }

  depends_on = [aws_elasticache_parameter_group.this]
}

# ---------------------------------------------------------------------------
# CloudWatch alarms (optional)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = local.enabled && var.cloudwatch_metric_alarms_enabled ? local.member_clusters_count : 0

  alarm_name          = "${element(local.member_clusters, count.index)}-cpu-utilization"
  alarm_description   = "Redis node CPU utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold_percent

  dimensions = {
    CacheClusterId = element(local.member_clusters, count.index)
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = local.tags

  depends_on = [aws_elasticache_replication_group.this]
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  count = local.enabled && var.cloudwatch_metric_alarms_enabled ? local.member_clusters_count : 0

  alarm_name          = "${element(local.member_clusters, count.index)}-freeable-memory"
  alarm_description   = "Redis node freeable memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 60
  statistic           = "Average"
  threshold           = var.alarm_memory_threshold_bytes

  dimensions = {
    CacheClusterId = element(local.member_clusters, count.index)
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  tags          = local.tags

  depends_on = [aws_elasticache_replication_group.this]
}
