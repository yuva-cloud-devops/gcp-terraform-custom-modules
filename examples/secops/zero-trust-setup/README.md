# GCP Zero-Trust Security Infrastructure Example (WIF & IAP)

This example demonstrates deploying **Workload Identity Federation (WIF)** for GitHub Actions keyless CI/CD and **Identity-Aware Proxy (IAP)** TCP tunneling for secure, bastionless SSH/RDP access using the dynamic YAML-driven module `secops-infrastructure/zero-trust-security-infra`.

---

## 📁 Files

- `zero-trust.yaml`: Defines WIF pool, GitHub Actions OIDC provider with repository claims, dedicated service account with impersonation binding, and IAP TCP tunneling firewall and IAM accessors.
- `main.tf`: Instantiates `zero-trust-security-infra` with the YAML configuration.
- `provider.tf`: Configures the Google provider.
- `outputs.tf`: Exports pool names, provider IDs, service accounts, and IAP firewall/access details.

---

## 🚀 Deployment Instructions

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Review Plan
```bash
terraform plan
```

### 3. Apply
```bash
terraform apply
```

---

## 🧪 Testing WIF with GitHub Actions

In your GitHub repository workflow (`.github/workflows/deploy.yml`):

```yaml
name: GCP Keyless Auth Test
on: [push]

jobs:
  auth-test:
    runs-on: ubuntu-latest
    permissions:
      contents: 'read'
      id-token: 'write'

    steps:
      - uses: actions/checkout@v4

      - id: 'auth'
        uses: 'google-github-actions/auth@v2'
        with:
          workload_identity_provider: '<OUTPUT: workload_identity_providers.name>'
          service_account: '<OUTPUT: service_accounts.email>'

      - name: 'Test GCP CLI'
        run: 'gcloud storage ls'
```

---

## 🧪 Testing IAP TCP Forwarding (SSH without Public IP)

```bash
gcloud compute ssh <VM_NAME> \
  --zone=<ZONE> \
  --tunnel-through-iap \
  --project=yuvaraj-internal-project
```
