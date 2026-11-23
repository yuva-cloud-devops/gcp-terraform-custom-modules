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
# 0. Optional Reserved Regional Static External IP Addresses for Standalone VMs
# ------------------------------------------------------------------------------
resource "google_compute_address" "static_public_ips" {
  for_each = {
    for k, v in local.vm_instances_map : k => v
    if v.create_static_public_ip
  }

  name         = "${each.value.name}-public-ip"
  project      = each.value.project_id
  region       = each.value.region
  address_type = "EXTERNAL"
  description  = "Reserved static external IP address for standalone VM ${each.value.name}"
}

# ------------------------------------------------------------------------------
# 1. Standalone VM Instances Provisioned from an Instance Template
# ------------------------------------------------------------------------------
resource "google_compute_instance_from_template" "instances" {
  for_each = local.vm_instances_from_template

  name        = each.value.name
  project     = each.value.project_id
  zone        = each.value.zone
  description = each.value.description

  # Resilient in-place updates for machine type, metadata, and labels
  allow_stopping_for_update = true

  source_instance_template = try(
    google_compute_instance_template.templates[each.value.instance_template].self_link_unique,
    try(
      google_compute_instance_template.templates[each.value.instance_template].self_link,
      each.value.instance_template
    )
  )

  # Optional instance-level overrides
  machine_type        = each.value.machine_type != null && each.value.machine_type != "" ? each.value.machine_type : null
  can_ip_forward      = each.value.can_ip_forward
  tags                = each.value.tags
  labels              = each.value.labels
  deletion_protection = each.value.deletion_protection

  dynamic "network_interface" {
    for_each = length(each.value.network_interfaces) > 0 && (
      each.value.network_interfaces[0].subnetwork != null || each.value.enable_public_ip
    ) ? each.value.network_interfaces : []
    content {
      network    = network_interface.value.network
      subnetwork = network_interface.value.subnetwork
      network_ip = network_interface.value.network_ip

      dynamic "access_config" {
        for_each = network_interface.value.enable_public_ip ? [1] : []
        content {
          nat_ip = (
            network_interface.value.create_static_public_ip ?
            google_compute_address.static_public_ips[each.key].address :
            network_interface.value.nat_ip
          )
          network_tier = network_interface.value.network_tier
        }
      }
    }
  }

  metadata = length(each.value.metadata) > 0 ? each.value.metadata : null
}

# ------------------------------------------------------------------------------
# 2. Standalone VM Instances Provisioned with Custom Sizing/Disks
# ------------------------------------------------------------------------------
resource "google_compute_instance" "instances" {
  for_each = local.vm_instances_custom

  name         = each.value.name
  project      = each.value.project_id
  zone         = each.value.zone
  description  = each.value.description
  machine_type = each.value.machine_type

  # Resilient in-place updates for machine type, metadata, and labels
  allow_stopping_for_update = true

  can_ip_forward      = each.value.can_ip_forward
  tags                = each.value.tags
  labels              = each.value.labels
  deletion_protection = each.value.deletion_protection

  # Boot Disk
  boot_disk {
    auto_delete       = each.value.boot_disk.auto_delete
    kms_key_self_link = each.value.boot_disk.kms_key_name

    initialize_params {
      image = each.value.boot_disk.source_image
      type  = each.value.boot_disk.disk_type
      size  = each.value.boot_disk.disk_size_gb
    }
  }

  # Additional Attached Disks
  dynamic "attached_disk" {
    for_each = each.value.attached_disks
    content {
      source      = attached_disk.value.source
      device_name = attached_disk.value.device_name
      mode        = attached_disk.value.mode
    }
  }

  # Network Interfaces
  dynamic "network_interface" {
    for_each = each.value.network_interfaces
    content {
      network    = network_interface.value.network
      subnetwork = network_interface.value.subnetwork
      network_ip = network_interface.value.network_ip

      dynamic "access_config" {
        for_each = network_interface.value.enable_public_ip ? [1] : []
        content {
          nat_ip = (
            network_interface.value.create_static_public_ip ?
            google_compute_address.static_public_ips[each.key].address :
            network_interface.value.nat_ip
          )
          network_tier = network_interface.value.network_tier
        }
      }
    }
  }

  # Shielded VM Configuration
  shielded_instance_config {
    enable_secure_boot          = each.value.shielded_instance_config.enable_secure_boot
    enable_vtpm                 = each.value.shielded_instance_config.enable_vtpm
    enable_integrity_monitoring = each.value.shielded_instance_config.enable_integrity_monitoring
  }

  # Service Account
  dynamic "service_account" {
    for_each = each.value.service_account.email != null ? [1] : []
    content {
      email  = each.value.service_account.email
      scopes = each.value.service_account.scopes
    }
  }

  metadata = each.value.metadata
}

# ------------------------------------------------------------------------------
# 3. Resource Policy Attachments (Instance Schedules & Disk Snapshots)
# ------------------------------------------------------------------------------
resource "google_compute_instance_resource_policy_attachment" "vm_instance_schedules" {
  for_each = local.vm_instance_schedule_attachments

  name = try(
    google_compute_resource_policy.instance_schedules[each.value.instance_schedule].name,
    each.value.instance_schedule
  )
  instance = try(
    google_compute_instance_from_template.instances[each.key].name,
    google_compute_instance.instances[each.key].name
  )
  zone    = each.value.zone
  project = each.value.project_id
}

resource "google_compute_disk_resource_policy_attachment" "vm_boot_disk_snapshots" {
  for_each = local.vm_disk_snapshot_attachments

  name = try(
    google_compute_resource_policy.snapshot_schedules[each.value.snapshot_schedule].name,
    each.value.snapshot_schedule
  )
  disk = try(
    google_compute_instance_from_template.instances[each.key].name,
    google_compute_instance.instances[each.key].name
  )
  zone    = each.value.zone
  project = each.value.project_id
}
