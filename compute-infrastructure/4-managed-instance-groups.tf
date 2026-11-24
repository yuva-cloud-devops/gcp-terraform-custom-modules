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
# 1. Regional Managed Instance Groups (Multi-Zone High Availability)
# ------------------------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "regional_migs" {
  for_each = local.regional_migs_map

  name               = each.value.name
  project            = each.value.project_id
  region             = each.value.region
  description        = each.value.description
  base_instance_name = each.value.base_instance_name

  # self_link_unique ensures instantaneous detection of newly generated templates
  version {
    instance_template = try(
      google_compute_instance_template.templates[each.value.instance_template].self_link_unique,
      try(
        google_compute_instance_template.templates[each.value.instance_template].self_link,
        each.value.instance_template
      )
    )
  }

  # When autoscaling is enabled, target_size must be null to avoid conflicting with autoscaler
  target_size        = contains(local.migs_with_autoscalers, each.key) ? null : each.value.target_size
  target_pools       = each.value.target_pools
  wait_for_instances = each.value.wait_for_instances

  distribution_policy_zones        = each.value.distribution_policy_zones
  distribution_policy_target_shape = "EVEN"

  update_policy {
    type                  = each.value.update_policy.type
    minimal_action        = each.value.update_policy.minimal_action
    # In Regional MIGs, GCP requires max_surge_fixed to be either 0 or at least equal to the number of distribution zones
    max_surge_fixed       = each.value.update_policy.type == "PROACTIVE" ? (each.value.update_policy.max_surge_fixed > 0 && each.value.update_policy.max_surge_fixed < length(each.value.distribution_policy_zones) ? length(each.value.distribution_policy_zones) : each.value.update_policy.max_surge_fixed) : null
    max_unavailable_fixed = each.value.update_policy.max_unavailable_fixed
    replacement_method    = each.value.update_policy.replacement_method
  }

  dynamic "auto_healing_policies" {
    for_each = each.value.auto_healing_policies.health_check != null ? [1] : []
    content {
      health_check = try(
        google_compute_health_check.health_checks[each.value.auto_healing_policies.health_check].id,
        each.value.auto_healing_policies.health_check
      )
      initial_delay_sec = each.value.auto_healing_policies.initial_delay_sec
    }
  }

  dynamic "named_port" {
    for_each = each.value.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [target_size]
  }
}

# ------------------------------------------------------------------------------
# 2. Zonal Managed Instance Groups (Single-Zone Stateful/Batch Workloads)
# ------------------------------------------------------------------------------
resource "google_compute_instance_group_manager" "zonal_migs" {
  for_each = local.zonal_migs_map

  name               = each.value.name
  project            = each.value.project_id
  zone               = each.value.zone
  description        = each.value.description
  base_instance_name = each.value.base_instance_name

  # self_link_unique ensures instantaneous detection of newly generated templates
  version {
    instance_template = try(
      google_compute_instance_template.templates[each.value.instance_template].self_link_unique,
      try(
        google_compute_instance_template.templates[each.value.instance_template].self_link,
        each.value.instance_template
      )
    )
  }

  # When autoscaling is enabled, target_size must be null to avoid conflicting with autoscaler
  target_size        = contains(local.migs_with_autoscalers, each.key) ? null : each.value.target_size
  target_pools       = each.value.target_pools
  wait_for_instances = each.value.wait_for_instances

  update_policy {
    type                  = each.value.update_policy.type
    minimal_action        = each.value.update_policy.minimal_action
    max_surge_fixed       = each.value.update_policy.type == "PROACTIVE" ? each.value.update_policy.max_surge_fixed : null
    max_unavailable_fixed = each.value.update_policy.max_unavailable_fixed
    replacement_method    = each.value.update_policy.replacement_method
  }

  dynamic "auto_healing_policies" {
    for_each = each.value.auto_healing_policies.health_check != null ? [1] : []
    content {
      health_check = try(
        google_compute_health_check.health_checks[each.value.auto_healing_policies.health_check].id,
        each.value.auto_healing_policies.health_check
      )
      initial_delay_sec = each.value.auto_healing_policies.initial_delay_sec
    }
  }

  dynamic "named_port" {
    for_each = each.value.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [target_size]
  }
}
