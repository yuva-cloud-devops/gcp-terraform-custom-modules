# Unified Storage Infrastructure Example Setup

This example demonstrates deploying **`storage-infrastructure`** as a single, dynamic, and resilient module.

---

## Capabilities Demonstrated

1. **Cloud Storage (GCS)**:
   - Enforced Uniform Bucket-Level Access (`UBLA`)
   - Enforced Public Access Prevention
   - Object Versioning enabled
   - Automated Lifecycle Rules (Transition to Nearline at 30 days, purge at 365 days)
2. **Compute Persistent Disks & Snapshot Schedules**:
   - Automated Disaster Recovery Snapshot Schedule (`daily-backup-policy`)
   - Zonal Persistent Disk (`pd-balanced`) automatically attached to the snapshot policy
3. **Conditional Filestore**:
   - Filestore block is commented out; Terraform skips NFS creation with zero errors. Uncommenting provisions the Filestore NFS instance seamlessly.

---

## Deployment Steps

```bash
terraform init
terraform plan
terraform apply
```

---

## Verification Commands

1. **Verify GCS Bucket**:
   ```bash
   gcloud storage buckets describe gs://secops-demo-app-bucket-9862
   ```

2. **Verify Compute Disk & Snapshot Policy**:
   ```bash
   gcloud compute disks describe secops-demo-data-disk --zone=asia-south1-a
   gcloud compute resource-policies describe daily-backup-policy --region=asia-south1
   ```
