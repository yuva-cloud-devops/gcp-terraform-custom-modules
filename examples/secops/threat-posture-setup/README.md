# Threat Posture Setup Reference Example

This reference setup demonstrates how to deploy **Security Command Center (SCC)** real-time finding notifications and **Cloud Asset Inventory (CAI)** drift feeds using the dynamic `threat-posture-infra` custom module.

---

## Prerequisites

Enable the required GCP APIs in your project:
```powershell
gcloud services enable `
    securitycenter.googleapis.com `
    cloudasset.googleapis.com `
    pubsub.googleapis.com `
    --project=yuvaraj-internal-project
```

---

## Deployment

1. Initialize Terraform:
   ```powershell
   terraform init
   ```

2. Review the plan:
   ```powershell
   terraform plan
   ```

3. Deploy resources:
   ```powershell
   terraform apply -auto-approve
   ```

---

## Verification

### 1. Verify Security Command Center Notifications
```powershell
gcloud scc notifications list --project=yuvaraj-internal-project
```

### 2. Verify Cloud Asset Inventory Feeds
```powershell
gcloud asset feeds list --project=yuvaraj-internal-project
```

---

## Teardown

```powershell
terraform destroy -auto-approve
```
