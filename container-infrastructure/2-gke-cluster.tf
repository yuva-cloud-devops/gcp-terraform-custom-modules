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
# 1. Dedicated Least-Privilege GKE Node Service Account
# ------------------------------------------------------------------------------
resource "google_service_account" "gke_nodes" {
  for_each = {
    for k, v in local.clusters : k => v
    if v.create_service_account && v.node_service_account == null
  }

  account_id   = "${substr(each.value.name, 0, 24)}-nodes"
  display_name = "Dedicated GKE Node SA for ${each.value.name}"
  project      = each.value.project_id
  description  = "Least privilege Service Account for GKE cluster nodes"
}

# Standard GCP GKE Node Hardened IAM Roles
locals {
  gke_node_standard_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader" # Auto-grants image pull access to Artifact Registry
  ]

  # Cartesian product for per-cluster role bindings
  cluster_node_roles = flatten([
    for cluster_key, cluster in local.clusters : [
      for role in local.gke_node_standard_roles : {
        key         = "${cluster_key}-${role}"
        cluster_key = cluster_key
        project_id  = cluster.project_id
        role        = role
      }
    ] if cluster.create_service_account && cluster.node_service_account == null
  ])
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = {
    for item in local.cluster_node_roles : item.key => item
  }

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.gke_nodes[each.value.cluster_key].email}"
}

# ------------------------------------------------------------------------------
# 2. GKE Cluster Control Plane (Supports STANDARD and AUTOPILOT)
# ------------------------------------------------------------------------------
resource "google_container_cluster" "clusters" {
  for_each = local.clusters

  name     = each.value.name
  project  = each.value.project_id
  location = each.value.location

  network    = each.value.network
  subnetwork = each.value.subnetwork

  # Deletion protection toggle (set false for testing environments)
  deletion_protection = each.value.deletion_protection

  # Autopilot vs Standard Engine Mode
  enable_autopilot = each.value.mode == "AUTOPILOT" ? true : null

  # Modern GKE natively skips default node pool creation when initial_node_count
  # and node_config are omitted. Node pools are managed separately in 3-gke-node-pools.tf.

  # VPC-Native IP Allocation Policy (Secondary ranges for Pods and Services)
  ip_allocation_policy {
    cluster_secondary_range_name  = each.value.pods_secondary_range_name
    services_secondary_range_name = each.value.services_secondary_range_name
  }

  # Hardened Private Cluster Architecture
  private_cluster_config {
    enable_private_nodes    = each.value.enable_private_nodes
    enable_private_endpoint = each.value.enable_private_endpoint
    master_ipv4_cidr_block  = each.value.master_ipv4_cidr_block
  }

  # Master Authorized Networks (Gated control plane ingress)
  dynamic "master_authorized_networks_config" {
    for_each = length(each.value.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = each.value.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = try(cidr_blocks.value.display_name, null)
        }
      }
    }
  }

  # Release Channel (Google-managed upgrades & patches)
  release_channel {
    channel = each.value.release_channel
  }

  # GKE Datapath v2 (eBPF / Cilium for high performance and NetworkPolicies)
  datapath_provider = each.value.mode == "STANDARD" ? each.value.datapath_provider : null

  # GKE Workload Identity Federation (Direct Pod-to-GCP authentication)
  dynamic "workload_identity_config" {
    for_each = each.value.workload_identity ? [1] : []
    content {
      workload_pool = "${each.value.project_id}.svc.id.goog"
    }
  }

  # Cloud KMS Application-Layer Secrets Encryption (using existing KMS key if specified in YAML)
  dynamic "database_encryption" {
    for_each = each.value.enable_database_encryption && each.value.database_encryption_key != null ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = each.value.database_encryption_key
    }
  }

  # Secret Manager Add-on (Secrets Store CSI Driver) - only enabled when requested in YAML
  dynamic "secret_manager_config" {
    for_each = each.value.secret_manager_addon ? [1] : []
    content {
      enabled = true
    }
  }

  # GKE Gateway API Controller (Top-level block in google_container_cluster)
  dynamic "gateway_api_config" {
    for_each = each.value.gateway_api_channel != "CHANNEL_DISABLED" ? [1] : []
    content {
      channel = each.value.gateway_api_channel
    }
  }

  # ----------------------------------------------------------------------------
  # Addons Configuration (Ingress HTTP LB, CSI Drivers, DNS Cache)
  # ----------------------------------------------------------------------------
  addons_config {
    http_load_balancing {
      disabled = !each.value.http_load_balancing
    }

    dynamic "gcs_fuse_csi_driver_config" {
      for_each = each.value.gcs_fuse_csi_driver ? [1] : []
      content {
        enabled = true
      }
    }

    dynamic "gcp_filestore_csi_driver_config" {
      for_each = each.value.filestore_csi_driver ? [1] : []
      content {
        enabled = true
      }
    }

    dynamic "dns_cache_config" {
      for_each = each.value.mode == "STANDARD" && each.value.dns_cache_enabled ? [1] : []
      content {
        enabled = true
      }
    }
  }

  # Observability (System components, Workloads, API Server, etc.)
  dynamic "logging_config" {
    for_each = length(each.value.logging_components) > 0 ? [1] : []
    content {
      enable_components = each.value.logging_components
    }
  }

  dynamic "monitoring_config" {
    for_each = length(each.value.monitoring_components) > 0 ? [1] : []
    content {
      enable_components = each.value.monitoring_components
    }
  }

  # Security Posture Config (Workload vulnerability scanning)
  dynamic "security_posture_config" {
    for_each = each.value.security_posture_mode != "DISABLED" || each.value.vulnerability_mode != "VULNERABILITY_DISABLED" ? [1] : []
    content {
      mode               = each.value.security_posture_mode != "DISABLED" ? each.value.security_posture_mode : null
      vulnerability_mode = each.value.vulnerability_mode != "VULNERABILITY_DISABLED" ? each.value.vulnerability_mode : null
    }
  }

  # Maintenance Window Policy (Predictable, controlled update timing)
  dynamic "maintenance_policy" {
    for_each = each.value.maintenance_policy != null ? [each.value.maintenance_policy] : []
    content {
      daily_maintenance_window {
        start_time = try(maintenance_policy.value.start_time, "03:00")
      }
    }
  }

  resource_labels = each.value.labels

  lifecycle {
    ignore_changes = [
      node_config
    ]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gke_robot_encryption
  ]
}
