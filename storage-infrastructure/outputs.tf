# ==============================================================================
# Outputs: Storage Infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Cloud Storage (GCS) Outputs
# ------------------------------------------------------------------------------
output "buckets" {
  description = "Created Google Cloud Storage buckets."
  value = {
    for k, v in google_storage_bucket.buckets : k => {
      id        = v.id
      name      = v.name
      url       = v.url
      self_link = v.self_link
      location  = v.location
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Compute Disks Outputs
# ------------------------------------------------------------------------------
output "snapshot_policies" {
  description = "Created Compute Engine snapshot schedule resource policies."
  value = {
    for k, v in google_compute_resource_policy.snapshot_policies : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "zonal_disks" {
  description = "Created Zonal Persistent Disks."
  value = {
    for k, v in google_compute_disk.zonal_disks : k => {
      id        = v.id
      name      = v.name
      self_link = v.self_link
      zone      = v.zone
      size      = v.size
    }
  }
}

output "regional_disks" {
  description = "Created Regional Persistent Disks (HA Cross-Zone)."
  value = {
    for k, v in google_compute_region_disk.regional_disks : k => {
      id            = v.id
      name          = v.name
      self_link     = v.self_link
      region        = v.region
      replica_zones = v.replica_zones
      size          = v.size
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Filestore Outputs
# ------------------------------------------------------------------------------
output "filestore_instances" {
  description = "Created Filestore NFS instances."
  value = {
    for k, v in google_filestore_instance.instances : k => {
      id           = v.id
      name         = v.name
      location     = v.location
      tier         = v.tier
      ip_addresses = try(v.networks[0].ip_addresses, [])
    }
  }
}

# ------------------------------------------------------------------------------
# 4. Summary Metrics
# ------------------------------------------------------------------------------
output "storage_summary" {
  description = "Summary count of provisioned storage resources."
  value = {
    total_buckets             = length(google_storage_bucket.buckets)
    total_snapshot_policies   = length(google_compute_resource_policy.snapshot_policies)
    total_zonal_disks         = length(google_compute_disk.zonal_disks)
    total_regional_disks      = length(google_compute_region_disk.regional_disks)
    total_filestore_instances = length(google_filestore_instance.instances)
  }
}
