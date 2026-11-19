# GCP Audit & Compliance Infrastructure Example

This example demonstrates deploying enterprise GCP Audit Logging, Centralized SIEM Log Sinks, Compliance WORM Storage, and CIS GCP Foundations Benchmark security metrics using the dynamic YAML-driven module `secops-infrastructure/audit-compliance-infra`.

---

## 📁 Files

- `audit-compliance.yaml`: Configuration defining audit logging services, storage bucket with retention policy, BigQuery analytics dataset, Pub/Sub streaming topic, log sinks with exclusions, and CIS Benchmark security metrics.
- `main.tf`: Instantiates `audit-compliance-infra` with the YAML configuration.
- `provider.tf`: Configures the Google provider.
- `outputs.tf`: Exports sinks, writer identities, storage destinations, security metrics, and deployment summary.

---

## 🚀 Deployment Instructions

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Validate Configuration
```bash
terraform validate
```

### 3. Review Plan
```bash
terraform plan
```

### 4. Apply
```bash
terraform apply
```
