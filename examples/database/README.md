# Database Infrastructure Example

This example demonstrates how to consume the unified `database-infrastructure` Terraform module using YAML-driven configuration.

## Features Deployed

- **Cloud SQL**: PostgreSQL 15 instance with `REGIONAL` multi-zone HA failover, SSD storage auto-resize, SSL enforcement, automated 7-day backups with Point-in-Time Recovery (PITR), logical database `app_production`, and user `app_user`.
- **AlloyDB for PostgreSQL**: Enterprise cluster with 14-day continuous backup retention, weekly automated backup schedule, primary compute instance, and an auto-scaled read pool.
- **Memorystore Redis**: In-memory caching with `STANDARD_HA` cross-zone failover, RDB persistence snapshotting every 12 hours, Redis AUTH password protection, and server TLS encryption.
- **Firestore**: Native serverless NoSQL database with deletion protection, Point-in-Time Recovery (PITR), and an automated 14-day daily backup schedule.

## Deployment Instructions

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply deployment
terraform apply -auto-approve
```
