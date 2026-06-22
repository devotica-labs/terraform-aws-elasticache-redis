# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## [Unreleased]

### Added
- Initial module — a native (no external module dependencies) ElastiCache for
  Redis replication group with:
  - At-rest encryption (AWS-managed or customer KMS key) and in-transit TLS,
    both on by default.
  - Automatic failover + Multi-AZ + a 2-node default so HA works out of the box.
  - Redis Cluster (sharded) mode, RBAC user groups / AUTH token, automated
    snapshots with a 7-day default retention and optional final snapshot.
  - A dedicated security group (ingress from configured source SGs / CIDRs on
    the Redis port; all egress) — or bring your own.
  - Parameter group (create or BYO), slow-log / engine-log delivery, and
    optional CPU + freeable-memory CloudWatch alarms.
  - Native naming/tagging composed from `namespace`/`environment`/`stage`/`name`.
  - `examples/basic` + `examples/complete`, and unit/contract/integration
    `terraform test` suites.

### Deferred to later versions
- Serverless ElastiCache.
- Global datastore (cross-region replication).
- A `sample-infra/redis` consumer service.
