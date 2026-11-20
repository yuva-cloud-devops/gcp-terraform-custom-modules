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
# Cloud Bigtable Instances (High-Throughput / Ultra Low-Latency NoSQL)
# ------------------------------------------------------------------------------

resource "google_bigtable_instance" "instances" {
  for_each = local.bigtable_instances_map

  name                = each.value.name
  project             = each.value.project_id
  display_name        = each.value.display_name
  deletion_protection = each.value.deletion_protection
  labels              = each.value.labels

  dynamic "cluster" {
    for_each = each.value.clusters
    content {
      cluster_id   = cluster.value.cluster_id
      zone         = cluster.value.zone
      num_nodes    = try(cluster.value.autoscaling_config, null) == null ? try(cluster.value.num_nodes, 1) : null
      storage_type = try(cluster.value.storage_type, "SSD")
      kms_key_name = try(cluster.value.kms_key_name, null)

      dynamic "autoscaling_config" {
        for_each = try(cluster.value.autoscaling_config, null) != null ? [cluster.value.autoscaling_config] : []
        content {
          min_nodes  = autoscaling_config.value.min_nodes
          max_nodes  = autoscaling_config.value.max_nodes
          cpu_target = autoscaling_config.value.cpu_target
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Cloud Bigtable Tables & Column Families
# ------------------------------------------------------------------------------

resource "google_bigtable_table" "tables" {
  for_each = local.bigtable_tables_map

  name          = each.value.name
  instance_name = try(google_bigtable_instance.instances[each.value.instance_name].name, each.value.instance_name)
  project       = each.value.project_id
  split_keys    = each.value.split_keys

  dynamic "column_family" {
    for_each = each.value.column_families
    content {
      family = try(column_family.value.family, tostring(column_family.value))
    }
  }

  depends_on = [
    google_bigtable_instance.instances
  ]
}
