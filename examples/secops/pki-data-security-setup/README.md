# PKI & Data Security Infrastructure Setup Example

This example demonstrates deploying **Certificate Authority Service (CAS)**, **Certificate Manager**, and **Cloud DLP** via `secops-infrastructure/pki-data-security-infra`.

---

## 🛠️ Prerequisites

Ensure the following Google Cloud APIs are enabled in your project:

```powershell
gcloud services enable privateca.googleapis.com `
                       certificatemanager.googleapis.com `
                       dlp.googleapis.com `
                       --project=yuvaraj-internal-project
```

---

## 🚀 Deployment

```powershell
terraform init
terraform plan
terraform apply -auto-approve
```

---

## 🔍 Verification

```powershell
# 1. Verify Private CA Pool
gcloud privateca pools list --location=asia-south1 --project=yuvaraj-internal-project

# 2. Verify Root Certificate Authority
gcloud privateca roots list --pool=secops-devops-ca-pool --location=asia-south1 --project=yuvaraj-internal-project

# 3. Verify Certificate Map
gcloud certificate-manager maps list --project=yuvaraj-internal-project

# 4. Verify DLP Inspection Templates
gcloud dlp inspect-templates list --project=yuvaraj-internal-project
```

---

## 🧹 Cleanup

```powershell
terraform destroy -auto-approve
```
