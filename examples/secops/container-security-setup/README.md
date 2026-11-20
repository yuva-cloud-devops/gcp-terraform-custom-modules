# Container Security Infrastructure Example Setup

This example demonstrates how to deploy **Module 7: `container-security-infra`** to enforce **Binary Authorization** and manage **Container Analysis (Grafeas) Attestation Notes**.

---

## Prerequisites

Enable the required Google Cloud APIs:

```bash
gcloud services enable \
  containeranalysis.googleapis.com \
  binaryauthorization.googleapis.com \
  --project=yuvaraj-internal-project
```

---

## Deployment Steps

```bash
terraform init
terraform plan
terraform apply
```

---

## Testing & Verification

1. **Verify Container Analysis Note**:
   ```bash
   gcloud container analysis notes describe secops-security-attestation-note --project=yuvaraj-internal-project
   ```

2. **Verify Binary Authorization Attestor**:
   ```bash
   gcloud container binauthz attestors describe secops-security-attestor --project=yuvaraj-internal-project
   ```

3. **Verify Binary Authorization Policy**:
   ```bash
   gcloud container binauthz policy export --project=yuvaraj-internal-project
   ```

4. **Verify in Google Cloud Console**:
   - Navigate to **Security** > **Binary Authorization** to view the active policy and attestors.
   - Navigate to **Artifact Registry / Container Analysis** to view metadata notes.
