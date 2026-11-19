# End-to-End Crypto & Secrets Infrastructure Example

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Declarative YAML](https://img.shields.io/badge/Config-crypto--secrets.yaml-orange.svg)](crypto-secrets.yaml)

This example demonstrates how to deploy an enterprise-grade cryptographic key management and secrets infrastructure in Google Cloud Platform using the [`crypto-secrets-infra`](../../../secops-infrastructure/crypto-secrets-infra) custom Terraform module driven entirely by [`crypto-secrets.yaml`](crypto-secrets.yaml).

---

## What This Example Deploys

1. **Cloud KMS Keyring**:
   - `secops-keyring-mumbai` provisioned in region `asia-south1`.
   - Keyring-level audit reader IAM permissions for security auditors.
2. **Cloud KMS CryptoKeys**:
   - `cmek-gke-etcd`: Symmetric software key with 90-day rotation and CMEK IAM delegation to GKE Container Engine Robot.
   - `cmek-cloud-sql`: Symmetric FIPS 140-2 Level 3 **Cloud HSM** key with 30-day rotation and CMEK IAM delegation to Cloud SQL service identity.
   - `cmek-storage-analytics`: Symmetric key with 90-day rotation delegated to GCS & BigQuery service agents.
   - `app-code-signing-key`: Asymmetric **Cloud HSM** digital signing key (`RSA_SIGN_PSS_2048_SHA256`) delegated to CI/CD release pipeline service accounts.
3. **Secret Manager Secrets**:
   - `db-credentials-master`: Encrypted with Customer-Managed Encryption Key (`cmek-cloud-sql`), automated 30-day rotation notification, Pub/Sub alert topic integration, initial version payload, and database accessor IAM.
   - `oauth-jwt-private-key`: Multi-region user-managed replication across `asia-south1` (Mumbai) and `asia-south2` (Delhi) with identity service accessor IAM.
   - `payment-gateway-api-token`: Automatic replication with 90-day time-to-live (`ttl`) and temporal CEL IAM condition.

---

## Directory Structure

```
examples/secops/crypto-secrets-setup/
├── crypto-secrets.yaml    # Declarative YAML definition
├── main.tf                # Module invocation
├── provider.tf            # Terraform & Google provider constraints
├── outputs.tf             # Output variables
└── README.md              # Documentation
```

---

## Prerequisites

1. **Terraform**: `>= 1.5.0`
2. **GCP Project**: A target Google Cloud project with billing enabled.
3. **Required GCP APIs**:
   ```bash
   gcloud services enable \
     cloudkms.googleapis.com \
     secretmanager.googleapis.com
   ```
4. **Authentication**:
   ```bash
   gcloud auth application-default login
   ```

---

## Quick Start

### 1. Configure Target Project
Open [`crypto-secrets.yaml`](crypto-secrets.yaml) and update `project_id` and service account numbers to match your GCP environment:

```yaml
project_id: "YOUR_PROJECT_ID"
default_location: "asia-south1"
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Review Plan
```bash
terraform plan
```

### 4. Deploy Infrastructure
```bash
terraform apply
```

### 5. Inspect Outputs
```bash
terraform output summary
terraform output key_ids
terraform output secret_ids
```

---

## Clean Up

To destroy the provisioned resources:

```bash
terraform destroy
```
