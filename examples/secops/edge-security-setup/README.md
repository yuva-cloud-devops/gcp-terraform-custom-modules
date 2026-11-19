# Edge Security Setup Example (Cloud Armor, Cloud IDS, VPC SC)

This example demonstrates how to deploy the **`edge-security-infra`** module using a single declarative YAML file.

## Provisioned Components
- **Cloud Armor Security Policy**: `secops-edge-waf-policy` with preconfigured OWASP Top 10 mitigation rules (SQLi, XSS, Scanner detection), Layer 7 rate limiting (throttles > 100 req/min per IP), and Adaptive Protection.

## How to Deploy and Test

```powershell
terraform init
terraform plan
terraform apply
```

## How to Verify Cloud Armor WAF in GCP

```powershell
# Describe Cloud Armor Policy
gcloud compute security-policies describe secops-edge-waf-policy --project=yuvaraj-internal-project

# List all rules configured under the policy
gcloud compute security-policies rules list --security-policy=secops-edge-waf-policy --project=yuvaraj-internal-project
```
