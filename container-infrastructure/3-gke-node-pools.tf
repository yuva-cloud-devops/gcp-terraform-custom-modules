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
# 3. Dedicated GKE Node Pools (for GKE Standard Clusters)
# ------------------------------------------------------------------------------
resource "google_container_node_pool" "pools" {
  for_each = local.node_pools

  name       = each.value.name
  cluster    = google_container_cluster.clusters[each.value.cluster_key].name
  location   = each.value.location
  project    = each.value.project_id
  node_count = each.value.autoscaling == null ? each.value.initial_node_count : null

  initial_node_count = each.value.autoscaling != null ? each.value.initial_node_count : null

  # Node Autoscaling (Horizontal cluster autoscaling)
  dynamic "autoscaling" {
    for_each = each.value.autoscaling != null ? [each.value.autoscaling] : []
    content {
      min_node_count       = autoscaling.value.min_node_count
      max_node_count       = autoscaling.value.max_node_count
      total_min_node_count = autoscaling.value.total_min_node_count
      total_max_node_count = autoscaling.value.total_max_node_count
    }
  }

  # Node Management (Auto-repair and auto-upgrade)
  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  # Node Compute & Security Configuration
  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    spot         = each.value.spot
    preemptible  = each.value.preemptible

    # Dedicated Least Privilege Node Service Account
    service_account = (
      local.clusters[each.value.cluster_key].node_service_account != null ?
      local.clusters[each.value.cluster_key].node_service_account :
      (
        local.clusters[each.value.cluster_key].create_service_account ?
        google_service_account.gke_nodes[each.value.cluster_key].email :
        null
      )
    )

    # Hardened OAuth Scopes - Best practice when paired with custom IAM SA
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Shielded VM Configuration
    shielded_instance_config {
      enable_secure_boot          = each.value.enable_secure_boot
      enable_integrity_monitoring = each.value.enable_integrity_monitoring
    }

    # Workload Identity Metadata Concealment (GKE_METADATA)
    dynamic "workload_metadata_config" {
      for_each = local.clusters[each.value.cluster_key].workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }

    labels = each.value.labels
    tags   = each.value.tags

    # Kubernetes Node Taints for dedicated / isolated workloads
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }
}
