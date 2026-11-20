# Unified Storage Infrastructure Module (`storage-infrastructure`)

Production-grade, resilient, and dynamic YAML-driven Terraform module for Google Cloud Platform **Storage Infrastructure**, covering **Cloud Storage (GCS)**, **Compute Persistent Disks & Snapshot Schedules**, and **Filestore (NFS)**.

---

## Architectural Principles: Efficiency & Resilience

- **100% Conditional Execution**: Define only the services you need. If a section (`gcs`, `compute_disks`, or `filestore`) is omitted from the YAML, Terraform creates zero resources for that section without errors.
- **Enterprise Security by Default**:
  - GCS buckets enforce `uniform_bucket_level_access = true` and `public_access_prevention = "enforced"` out of the box.
  - Optional Customer-Managed Encryption Keys (`CMEK`) across GCS, Persistent Disks, and Filestore.
  - Compliant object retention (WORM / Bucket Lock) with retention period validation.
- **High-Availability & Disaster Recovery (DR)**:
  - Supports both **Zonal** and **Regional Persistent Disks** with synchronous active cross-zone replication.
  - Automated hourly, daily, or weekly snapshot schedules with automatic retention and policy attachment.
  - `guest_flush = true` support for VSS / filesystem application-consistent disk snapshots.
  - Filestore NFS shares with granular client export rules (`nfs_export_options`).

---

## YAML Configuration Specification

```yaml
storage_infrastructure:
  project_id: "my-gcp-project"
  region: "asia-south1"

  # =========================================================================
  # 1. CLOUD STORAGE (GCS) - [OPTIONAL]
  # =========================================================================
  gcs:
    buckets:
      app-data-bucket-prod:
        location: "asia-south1"
        storage_class: "STANDARD"
        uniform_bucket_level_access: true
        public_access_prevention: "enforced"
        versioning: true
        force_destroy: false
        # Optional WORM / Retention Lock
        retention_policy:
          retention_period_days: 30
          is_locked: false
        # Lifecycle Transitions
        lifecycle_rules:
          - action:
              type: "SetStorageClass"
              storage_class: "NEARLINE"
            condition:
              age: 30
          - action:
              type: "SetStorageClass"
              storage_class: "COLDLINE"
            condition:
              age: 90
          - action:
              type: "Delete"
            condition:
              age: 365
              num_newer_versions: 3
        iam_members:
          - role: "roles/storage.objectViewer"
            member: "serviceAccount:my-app-sa@my-gcp-project.iam.gserviceaccount.com"

  # =========================================================================
  # 2. COMPUTE PERSISTENT DISKS & SNAPSHOT POLICIES - [OPTIONAL]
  # =========================================================================
  compute_disks:
    snapshot_policies:
      daily-dr-snapshot-policy:
        region: "asia-south1"
        schedule:
          daily:
            days_in_cycle: 1
            start_time: "02:00" # UTC
        retention_policy:
          max_retention_days: 14
          on_source_disk_delete: "KEEP_SNAPSHOTS"
        snapshot_properties:
          storage_locations: ["asia-south1"]
          guest_flush: true

    zonal_disks:
      db-data-disk-01:
        zone: "asia-south1-a"
        size_gb: 50
        type: "pd-balanced"
        snapshot_policy: "daily-dr-snapshot-policy"

    regional_disks:
      ha-cluster-shared-disk:
        region: "asia-south1"
        replica_zones:
          - "asia-south1-a"
          - "asia-south1-b"
        size_gb: 100
        type: "pd-balanced"
        snapshot_policy: "daily-dr-snapshot-policy"

  # =========================================================================
  # 3. FILESTORE (NFS FILE SHARES) - [OPTIONAL]
  # =========================================================================
  filestore:
    instances:
      shared-nfs-store:
        zone: "asia-south1-a"
        tier: "BASIC_HDD"
        file_shares:
          name: "vol1"
          capacity_gb: 1024
          nfs_export_options:
            - ip_ranges: ["10.10.0.0/16"]
              access_mode: "READ_WRITE"
              squash_mode: "NO_ROOT_SQUASH"
        network:
          name: "default"
          modes: ["MODE_IPV4"]
          connect_mode: "DIRECT_PEERING"
```

---

## Terraform Usage

```hcl
module "storage_infrastructure" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//storage-infrastructure?ref=main"
  config_file_path = "./storage-infrastructure.yaml"
}

output "storage_summary" {
  value = module.storage_infrastructure.storage_summary
}

output "buckets" {
  value = module.storage_infrastructure.buckets
}

output "zonal_disks" {
  value = module.storage_infrastructure.zonal_disks
}

output "regional_disks" {
  value = module.storage_infrastructure.regional_disks
}

output "filestore" {
  value = module.storage_infrastructure.filestore_instances
}
```
