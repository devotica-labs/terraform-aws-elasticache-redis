#!/usr/bin/env python3
"""Render an ElastiCache Redis architecture diagram from a Terraform plan JSON.

Centres the replication group in its VPC, with edges to:
  - the security group fronting it
  - the subnet group
  - KMS (when at-rest encryption uses a CMK)
  - CloudWatch alarms (when enabled)

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.database import ElastiCache
from diagrams.aws.management import Cloudwatch
from diagrams.aws.network import VPC
from diagrams.aws.security import KMS


def load_resources(plan_path: Path) -> list[dict]:
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = {}
    for r in resources:
        by_type.setdefault(r["type"], []).append(r)

    rgs = by_type.get("aws_elasticache_replication_group", [])
    if not rgs:
        raise SystemExit("No aws_elasticache_replication_group found in plan — nothing to render.")

    rg = values(rgs[0])
    name = rg.get("replication_group_id") or "redis"
    node_type = rg.get("node_type", "?")
    num_nodes = rg.get("num_cache_clusters")
    cluster_mode = bool(rg.get("num_node_groups"))
    at_rest = bool(rg.get("at_rest_encryption_enabled"))
    transit = bool(rg.get("transit_encryption_enabled"))
    failover = bool(rg.get("automatic_failover_enabled"))
    multi_az = bool(rg.get("multi_az_enabled"))
    has_cmk = bool(rg.get("kms_key_id"))

    has_sg = bool(by_type.get("aws_security_group"))
    has_subnet_group = bool(by_type.get("aws_elasticache_subnet_group"))
    alarms = by_type.get("aws_cloudwatch_metric_alarm", [])

    badges = []
    if cluster_mode:
        badges.append("cluster mode")
    elif num_nodes:
        badges.append(f"{num_nodes} nodes")
    enc = []
    if at_rest:
        enc.append("at-rest" + ("+CMK" if has_cmk else ""))
    if transit:
        enc.append("TLS")
    if enc:
        badges.append(" / ".join(enc))
    if failover:
        badges.append("failover")
    if multi_az:
        badges.append("multi-AZ")

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "1.0",
        "nodesep": "0.6",
        "pad": "0.5",
    }

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-elasticache-redis — {name} ({node_type}) · {' · '.join(badges)}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        vpc = VPC("VPC\nprivate subnets")

        with Cluster(f"ElastiCache — {name}"):
            cache = ElastiCache(f"Redis\n{node_type}")
            label = "subnet group + SG" if (has_subnet_group and has_sg) else "subnet group"
            vpc >> Edge(label=label) >> cache

            if has_cmk:
                KMS("KMS key") >> Edge(style="dashed", label="encrypts at rest") >> cache

            if alarms:
                with Cluster("CloudWatch alarms"):
                    Cloudwatch("CPU")
                    Cloudwatch("memory")


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: render-architecture.py <plan.json> <output-path-without-ext>\n")
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
