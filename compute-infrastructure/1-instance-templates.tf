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

resource "google_compute_instance_template" "templates" {
  for_each = local.instance_templates_map

  name_prefix  = each.value.name_prefix
  project      = each.value.project_id
  region       = each.value.region
  description  = each.value.description
  machine_type = each.value.machine_type

  can_ip_forward = each.value.can_ip_forward
  tags           = each.value.tags
  labels         = each.value.labels

  # Primary Boot Disk
  disk {
    source_image = each.value.boot_disk.source_image
    auto_delete  = each.value.boot_disk.auto_delete
    boot         = true
    disk_type    = each.value.boot_disk.disk_type
    disk_size_gb = each.value.boot_disk.disk_size_gb

    dynamic "disk_encryption_key" {
      for_each = each.value.boot_disk.kms_key_name != null ? [1] : []
      content {
        kms_key_self_link = each.value.boot_disk.kms_key_name
      }
    }

    resource_policies = [
      for p in each.value.boot_disk.resource_policies :
      try(google_compute_resource_policy.snapshot_schedules[p].self_link, p)
    ]
  }

  # Additional Persistent Disks
  dynamic "disk" {
    for_each = each.value.additional_disks
    content {
      device_name  = disk.value.device_name
      disk_name    = disk.value.disk_name
      auto_delete  = disk.value.auto_delete
      boot         = false
      disk_type    = disk.value.disk_type
      disk_size_gb = disk.value.disk_size_gb
      mode         = disk.value.mode
      dynamic "disk_encryption_key" {
        for_each = try(disk.value.kms_key_name, null) != null ? [1] : []
        content {
          kms_key_self_link = disk.value.kms_key_name
        }
      }
      resource_policies = [
        for p in disk.value.resource_policies :
        try(google_compute_resource_policy.snapshot_schedules[p].self_link, p)
      ]
    }
  }

  # Network Interfaces
  dynamic "network_interface" {
    for_each = each.value.network_interfaces
    content {
      network    = network_interface.value.network
      subnetwork = network_interface.value.subnetwork

      dynamic "access_config" {
        for_each = network_interface.value.enable_public_ip ? [1] : []
        content {
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

  lifecycle {
    create_before_destroy = true
  }
}
