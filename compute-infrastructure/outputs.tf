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
# 1. Instance Templates
# ------------------------------------------------------------------------------
output "instance_templates" {
  description = "Map of all provisioned Google Compute Instance Templates"
  value = {
    for k, v in google_compute_instance_template.templates : k => {
      id        = v.id
      name      = v.name
      self_link = v.self_link
      tags      = v.tags
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Standalone VM Instances
# ------------------------------------------------------------------------------
output "vm_instances" {
  description = "Map of all standalone VM instances (both template-derived and custom)"
  value = merge(
    {
      for k, v in google_compute_instance_from_template.instances : k => {
        id           = v.id
        name         = v.name
        self_link    = v.self_link
        zone         = v.zone
        machine_type = v.machine_type
        internal_ip  = try(v.network_interface[0].network_ip, null)
        external_ip  = try(v.network_interface[0].access_config[0].nat_ip, null)
        type         = "FROM_TEMPLATE"
      }
    },
    {
      for k, v in google_compute_instance.instances : k => {
        id           = v.id
        name         = v.name
        self_link    = v.self_link
        zone         = v.zone
        machine_type = v.machine_type
        internal_ip  = try(v.network_interface[0].network_ip, null)
        external_ip  = try(v.network_interface[0].access_config[0].nat_ip, null)
        type         = "CUSTOM"
      }
    }
  )
}

output "static_public_ips" {
  description = "Map of reserved regional static external IP addresses created for VMs"
  value = {
    for k, v in google_compute_address.static_public_ips : k => {
      id      = v.id
      name    = v.name
      address = v.address
      region  = v.region
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Health Checks
# ------------------------------------------------------------------------------
output "health_checks" {
  description = "Map of all autohealing and load balancer health checks"
  value = {
    for k, v in google_compute_health_check.health_checks : k => {
      id        = v.id
      name      = v.name
      self_link = v.self_link
      type      = v.type
    }
  }
}

# ------------------------------------------------------------------------------
# 4. Managed Instance Groups (Regional & Zonal)
# ------------------------------------------------------------------------------
output "managed_instance_groups" {
  description = "Map of all Managed Instance Groups (Regional and Zonal)"
  value = merge(
    {
      for k, v in google_compute_region_instance_group_manager.regional_migs : k => {
        id             = v.id
        name           = v.name
        self_link      = v.self_link
        instance_group = v.instance_group
        region         = v.region
        target_size    = v.target_size
        type           = "REGIONAL"
      }
    },
    {
      for k, v in google_compute_instance_group_manager.zonal_migs : k => {
        id             = v.id
        name           = v.name
        self_link      = v.self_link
        instance_group = v.instance_group
        zone           = v.zone
        target_size    = v.target_size
        type           = "ZONAL"
      }
    }
  )
}

# ------------------------------------------------------------------------------
# 5. Autoscaling Policies
# ------------------------------------------------------------------------------
output "autoscalers" {
  description = "Map of all autoscalers attached to Managed Instance Groups"
  value = merge(
    {
      for k, v in google_compute_region_autoscaler.regional_autoscalers : k => {
        id     = v.id
        name   = v.name
        target = v.target
        type   = "REGIONAL"
      }
    },
    {
      for k, v in google_compute_autoscaler.zonal_autoscalers : k => {
        id     = v.id
        name   = v.name
        target = v.target
        type   = "ZONAL"
      }
    }
  )
}

# ------------------------------------------------------------------------------
# 6. Compute Resource Policies (Snapshot & Instance Start/Stop Schedules)
# ------------------------------------------------------------------------------
output "compute_policies" {
  description = "Map of all disk snapshot and VM start/stop resource policies"
  value = {
    snapshot_schedules = {
      for k, v in google_compute_resource_policy.snapshot_schedules : k => {
        id        = v.id
        name      = v.name
        self_link = v.self_link
        region    = v.region
      }
    }
    instance_schedules = {
      for k, v in google_compute_resource_policy.instance_schedules : k => {
        id        = v.id
        name      = v.name
        self_link = v.self_link
        region    = v.region
      }
    }
  }
}

# ------------------------------------------------------------------------------
# 7. High-Level Summary
# ------------------------------------------------------------------------------
output "compute_summary" {
  description = "High-level summary of provisioned compute infrastructure components"
  value = {
    instance_templates_count      = length(google_compute_instance_template.templates)
    standalone_vms_count          = length(google_compute_instance_from_template.instances) + length(google_compute_instance.instances)
    health_checks_count           = length(google_compute_health_check.health_checks)
    managed_instance_groups_count = length(google_compute_region_instance_group_manager.regional_migs) + length(google_compute_instance_group_manager.zonal_migs)
    autoscalers_count             = length(google_compute_region_autoscaler.regional_autoscalers) + length(google_compute_autoscaler.zonal_autoscalers)
    snapshot_schedules_count      = length(google_compute_resource_policy.snapshot_schedules)
    instance_schedules_count      = length(google_compute_resource_policy.instance_schedules)
  }
}
