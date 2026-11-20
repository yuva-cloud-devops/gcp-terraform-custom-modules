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
# Memorystore Redis Instances (High-Resilience Multi-Zone Caching)
# ------------------------------------------------------------------------------

resource "google_redis_instance" "instances" {
  for_each = local.redis_instances_map

  name                    = each.value.name
  project                 = each.value.project_id
  region                  = each.value.region
  tier                    = each.value.tier
  memory_size_gb          = each.value.memory_size_gb
  redis_version           = each.value.redis_version
  display_name            = each.value.display_name
  authorized_network      = each.value.authorized_network
  connect_mode            = each.value.connect_mode
  reserved_ip_range       = each.value.reserved_ip_range
  auth_enabled            = each.value.auth_enabled
  transit_encryption_mode = each.value.transit_encryption_mode

  dynamic "persistence_config" {
    for_each = each.value.rdb_snapshot_period != null && each.value.tier == "STANDARD_HA" ? [1] : []
    content {
      persistence_mode    = "RDB"
      rdb_snapshot_period = each.value.rdb_snapshot_period
    }
  }

  labels = each.value.labels
}
