# ==============================================================================
# Compute Engine Persistent Disks (Zonal & Regional) & Snapshot Policies
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Snapshot Schedule Resource Policies
# ------------------------------------------------------------------------------
resource "google_compute_resource_policy" "snapshot_policies" {
  for_each = local.snapshot_policies_map

  name        = each.value.name
  project     = each.value.project_id
  region      = each.value.region
  description = each.value.description

  snapshot_schedule_policy {
    schedule {
      dynamic "hourly_schedule" {
        for_each = each.value.hourly_schedule != null ? [each.value.hourly_schedule] : []
        content {
          hours_in_cycle = hourly_schedule.value.hours_in_cycle
          start_time     = hourly_schedule.value.start_time
        }
      }

      dynamic "daily_schedule" {
        for_each = each.value.daily_schedule != null ? [each.value.daily_schedule] : []
        content {
          days_in_cycle = try(daily_schedule.value.days_in_cycle, 1)
          start_time    = daily_schedule.value.start_time
        }
      }

      dynamic "weekly_schedule" {
        for_each = each.value.weekly_schedule != null ? [each.value.weekly_schedule] : []
        content {
          dynamic "day_of_weeks" {
            for_each = try(weekly_schedule.value.day_of_weeks, weekly_schedule.value)
            content {
              day        = day_of_weeks.value.day
              start_time = day_of_weeks.value.start_time
            }
          }
        }
      }
    }

    retention_policy {
      max_retention_days    = each.value.max_retention_days
      on_source_disk_delete = each.value.on_source_disk_delete
    }

    snapshot_properties {
      storage_locations = each.value.storage_locations
      guest_flush       = each.value.guest_flush
      labels            = each.value.labels
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Zonal Persistent Disks
# ------------------------------------------------------------------------------
resource "google_compute_disk" "zonal_disks" {
  for_each = local.zonal_disks_map

  name                      = each.value.name
  project                   = each.value.project_id
  zone                      = each.value.zone
  size                      = each.value.size
  type                      = each.value.type
  image                     = each.value.image
  snapshot                  = each.value.snapshot
  physical_block_size_bytes = each.value.physical_block_size_bytes
  provisioned_iops          = each.value.provisioned_iops
  provisioned_throughput    = each.value.provisioned_throughput
  labels                    = each.value.labels

  dynamic "disk_encryption_key" {
    for_each = each.value.kms_key_self_link != null ? [1] : []
    content {
      kms_key_self_link = each.value.kms_key_self_link
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "zonal_attachments" {
  for_each = local.zonal_disk_attachments

  name    = try(google_compute_resource_policy.snapshot_policies[each.value.snapshot_policy].name, each.value.snapshot_policy)
  disk    = google_compute_disk.zonal_disks[each.key].name
  zone    = each.value.zone
  project = each.value.project_id

  depends_on = [
    google_compute_resource_policy.snapshot_policies,
    google_compute_disk.zonal_disks
  ]
}

# ------------------------------------------------------------------------------
# 3. Regional Persistent Disks (HA Synchronous Cross-Zone Replication)
# ------------------------------------------------------------------------------
resource "google_compute_region_disk" "regional_disks" {
  for_each = local.regional_disks_map

  name                      = each.value.name
  project                   = each.value.project_id
  region                    = each.value.region
  replica_zones             = each.value.replica_zones
  size                      = each.value.size
  type                      = each.value.type
  physical_block_size_bytes = each.value.physical_block_size_bytes
  labels                    = each.value.labels

  dynamic "disk_encryption_key" {
    for_each = each.value.kms_key_self_link != null ? [1] : []
    content {
      kms_key_name = each.value.kms_key_self_link
    }
  }
}

resource "google_compute_region_disk_resource_policy_attachment" "regional_attachments" {
  for_each = local.regional_disk_attachments

  name    = try(google_compute_resource_policy.snapshot_policies[each.value.snapshot_policy].name, each.value.snapshot_policy)
  disk    = google_compute_region_disk.regional_disks[each.key].name
  region  = each.value.region
  project = each.value.project_id

  depends_on = [
    google_compute_resource_policy.snapshot_policies,
    google_compute_region_disk.regional_disks
  ]
}
