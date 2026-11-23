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
# 1. Regional Autoscalers (Targeting Regional Managed Instance Groups)
# ------------------------------------------------------------------------------
resource "google_compute_region_autoscaler" "regional_autoscalers" {
  for_each = local.regional_autoscalers_map

  name        = each.value.name
  project     = each.value.project_id
  region      = try(local.regional_migs_map[each.value.mig_name].region, local.default_region)
  target      = try(google_compute_region_instance_group_manager.regional_migs[each.value.mig_name].id, each.value.mig_name)
  description = each.value.description

  autoscaling_policy {
    min_replicas    = each.value.min_replicas
    max_replicas    = each.value.max_replicas
    cooldown_period = each.value.cooldown_period

    cpu_utilization {
      target = each.value.cpu_target
    }

    dynamic "load_balancing_utilization" {
      for_each = each.value.load_balancing_target != null ? [1] : []
      content {
        target = each.value.load_balancing_target
      }
    }

    dynamic "scaling_schedules" {
      for_each = each.value.scaling_schedules
      content {
        name                  = scaling_schedules.value.name
        min_required_replicas = scaling_schedules.value.min_required_replicas
        schedule              = scaling_schedules.value.schedule
        time_zone             = scaling_schedules.value.time_zone
        duration_sec          = scaling_schedules.value.duration_sec
        disabled              = scaling_schedules.value.disabled
      }
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Zonal Autoscalers (Targeting Zonal Managed Instance Groups)
# ------------------------------------------------------------------------------
resource "google_compute_autoscaler" "zonal_autoscalers" {
  for_each = local.zonal_autoscalers_map

  name        = each.value.name
  project     = each.value.project_id
  zone        = try(local.zonal_migs_map[each.value.mig_name].zone, local.default_zone)
  target      = try(google_compute_instance_group_manager.zonal_migs[each.value.mig_name].id, each.value.mig_name)
  description = each.value.description

  autoscaling_policy {
    min_replicas    = each.value.min_replicas
    max_replicas    = each.value.max_replicas
    cooldown_period = each.value.cooldown_period

    cpu_utilization {
      target = each.value.cpu_target
    }

    dynamic "load_balancing_utilization" {
      for_each = each.value.load_balancing_target != null ? [1] : []
      content {
        target = each.value.load_balancing_target
      }
    }

    dynamic "scaling_schedules" {
      for_each = each.value.scaling_schedules
      content {
        name                  = scaling_schedules.value.name
        min_required_replicas = scaling_schedules.value.min_required_replicas
        schedule              = scaling_schedules.value.schedule
        time_zone             = scaling_schedules.value.time_zone
        duration_sec          = scaling_schedules.value.duration_sec
        disabled              = scaling_schedules.value.disabled
      }
    }
  }
}
