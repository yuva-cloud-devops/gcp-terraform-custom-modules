# Compute Infrastructure Example

This example demonstrates how to consume the unified `compute-infrastructure` custom Terraform module using 100% YAML-driven configuration.

## Features Deployed

1. **Compute Resource Policies**:
   - `daily-snapshot-schedule`: Automated daily disk snapshot schedule with 14-day retention.
   - `business-hours-schedule`: Business hours start/stop schedule (Mon-Fri 8:00 AM to 7:00 PM IST) for automated VM cost optimization.
2. **Reusable Instance Template**:
   - `web-app-template`: Hardened e2-medium template with Debian 12 golden image, Shielded VM config, automated `cloud_init` bootstrap installing NGINX, and the snapshot schedule attached directly to the boot disk.
3. **Standalone VM Instances**:
   - `bastion-jump-host`: Provisioned directly **from the instance template** with both start/stop and snapshot schedules attached.
   - `custom-standalone-vm`: Provisioned with custom sizing and dedicated cloud-init configuration.
4. **Autohealing Health Check**:
   - `web-app-health-check`: Regional HTTP health check on port 80 monitoring application liveness.
5. **Regional Managed Instance Group (MIG)**:
   - `web-app-regional-mig`: Highly available regional cluster distributed across 3 availability zones (`asia-south1-a`, `asia-south1-b`, `asia-south1-c`) consuming `web-app-template` with proactive rolling update and autohealing policies.
6. **Autoscaling Policy**:
   - `web-app-autoscaler`: Metric/CPU-driven autoscaler (target 70% CPU, min 1, max 5 replicas) with business-hours scaling schedule.

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
