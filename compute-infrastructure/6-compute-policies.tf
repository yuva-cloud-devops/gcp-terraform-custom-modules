/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# ------------------------------------------------------------------------------
# 1. Disk Snapshot Schedule Resource Policies
# ------------------------------------------------------------------------------
resource "google_compute_resource_policy" "snapshot_schedules" {
  for_each = local.snapshot_schedules_map

  name        = each.value.name
  project     = each.value.project_id
  region      = each.value.region
  description = each.value.description

  snapshot_schedule_policy {
    schedule {
      dynamic "hourly_schedule" {
        for_each = each.value.schedule_type == "hourly" ? [1] : []
        content {
          hours_in_cycle = each.value.hours_in_cycle
          start_time     = each.value.start_time
        }
      }

      dynamic "daily_schedule" {
        for_each = each.value.schedule_type == "daily" ? [1] : []
        content {
          days_in_cycle = 1
          start_time    = each.value.start_time
        }
      }

      dynamic "weekly_schedule" {
        for_each = each.value.schedule_type == "weekly" ? [1] : []
        content {
          day_of_weeks {
            day        = each.value.day_of_week
            start_time = each.value.start_time
          }
        }
      }
    }

    retention_policy {
      max_retention_days    = each.value.max_retention_days
      on_source_disk_delete = each.value.on_source_disk_delete
    }

    snapshot_properties {
      guest_flush       = each.value.guest_flush
      labels            = each.value.labels
      storage_locations = each.value.storage_locations
    }
  }
}

# ------------------------------------------------------------------------------
# 2. VM Instance Start/Stop Schedule Resource Policies
# ------------------------------------------------------------------------------
resource "google_compute_resource_policy" "instance_schedules" {
  for_each = local.instance_schedules_map

  name        = each.value.name
  project     = each.value.project_id
  region      = each.value.region
  description = each.value.description

  instance_schedule_policy {
    time_zone = each.value.time_zone

    dynamic "vm_start_schedule" {
      for_each = each.value.vm_start_schedule != null ? [1] : []
      content {
        schedule = each.value.vm_start_schedule
      }
    }

    dynamic "vm_stop_schedule" {
      for_each = each.value.vm_stop_schedule != null ? [1] : []
      content {
        schedule = each.value.vm_stop_schedule
      }
    }

    start_time      = each.value.init_time
    expiration_time = each.value.end_time
  }
}
