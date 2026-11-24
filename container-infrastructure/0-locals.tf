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

locals {
  # ----------------------------------------------------------------------------
  # Raw YAML Ingestion (Supports inline string or external file path)
  # ----------------------------------------------------------------------------
  raw_yaml = (
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? file(var.config_file_path) : ""
    )
  )

  parsed_config = try(yamldecode(local.raw_yaml), {})
  cfg           = try(local.parsed_config.container_infrastructure, local.parsed_config)

  # Top-level defaults
  default_project_id = try(local.cfg.project_id, null)
  default_region     = try(local.cfg.region, "asia-south1")
  default_network    = try(local.cfg.network, null)
  default_subnetwork = try(local.cfg.subnetwork, null)
  global_tags        = try(local.cfg.tags, {})

  # ----------------------------------------------------------------------------
  # 1. Artifact Registry Repositories
  # ----------------------------------------------------------------------------
  raw_registries = try(local.cfg.artifact_registries, try(local.cfg.registries, {}))

  artifact_registries = {
    for k, v in local.raw_registries : try(v.name, tostring(k)) => {
      name                   = try(v.name, tostring(k))
      project_id             = try(v.project_id, local.default_project_id)
      location               = try(v.location, try(v.region, local.default_region))
      format                 = upper(try(v.format, "DOCKER"))
      description            = try(v.description, "Artifact Registry repository ${try(v.name, tostring(k))}")
      mode                   = upper(try(v.mode, "STANDARD_REPOSITORY"))
      immutable_tags         = try(v.immutable_tags, false)
      vulnerability_scanning = try(v.vulnerability_scanning, false)
      labels                 = merge(local.global_tags, try(v.labels, {}))

      # Cleanup Policies
      cleanup_policies = try(v.cleanup_policies, {})
    }
  }

  # ----------------------------------------------------------------------------
  # 2. GKE Clusters (Standard & Autopilot)
  # ----------------------------------------------------------------------------
  raw_clusters = try(local.cfg.clusters, try(local.cfg.gke_clusters, {}))

  clusters = {
    for k, v in local.raw_clusters : try(v.name, tostring(k)) => {
      name       = try(v.name, tostring(k))
      project_id = try(v.project_id, local.default_project_id)
      location   = try(v.location, try(v.region, local.default_region))
      mode       = upper(try(v.mode, "STANDARD")) # "STANDARD" or "AUTOPILOT"

      # Networking
      network                       = try(v.network, local.default_network)
      subnetwork                    = try(v.subnetwork, local.default_subnetwork)
      pods_secondary_range_name     = v.pods_secondary_range_name
      services_secondary_range_name = v.services_secondary_range_name
      master_ipv4_cidr_block        = try(v.master_ipv4_cidr_block, "172.16.0.0/28")

      # Private Cluster & Master Authorized Networks
      enable_private_nodes       = try(v.enable_private_nodes, true)
      enable_private_endpoint    = try(v.enable_private_endpoint, false)
      master_authorized_networks = try(v.master_authorized_networks, [])

      # Release & Engine Configuration
      release_channel     = upper(try(v.release_channel, "REGULAR"))
      datapath_provider   = upper(try(v.datapath_provider, "ADVANCED_DATAPATH")) # Datapath v2 (eBPF)
      workload_identity   = try(v.workload_identity, true)
      deletion_protection = try(v.deletion_protection, false)
      maintenance_policy  = try(v.maintenance_policy, null)
      labels              = merge(local.global_tags, try(v.labels, {}))

      # GKE Addons & Gateway API Configurations
      http_load_balancing  = try(v.addons.http_load_balancing, true)
      gateway_api_channel  = upper(try(v.addons.gateway_api_channel, "CHANNEL_STANDARD")) # CHANNEL_STANDARD, CHANNEL_EXTENDED, CHANNEL_DISABLED
      gcs_fuse_csi_driver  = try(v.addons.gcs_fuse_csi_driver, false)
      filestore_csi_driver = try(v.addons.filestore_csi_driver, false)
      dns_cache_enabled    = try(v.addons.dns_cache, true)

      # Secret Manager Add-on (Secrets Store CSI Driver) - Default false, enabled only if requested
      secret_manager_addon = try(v.addons.secret_manager, try(v.secret_manager.enabled, false))

      # Cloud KMS Application-Layer Secrets Encryption (using external key if provided)
      database_encryption_key = try(v.database_encryption.key_name, null)
      enable_database_encryption = (
        try(v.database_encryption.enabled, false) && try(v.database_encryption.key_name, null) != null
      )
      grant_kms_iam = try(v.database_encryption.grant_gke_robot_iam, true)

      # Observability & Security Posture
      security_posture_mode = upper(try(v.security_posture.mode, "DISABLED"))
      vulnerability_mode    = upper(try(v.security_posture.vulnerability_mode, "VULNERABILITY_DISABLED"))
      logging_components    = try(v.logging_components, ["SYSTEM_COMPONENTS", "WORKLOADS"])
      monitoring_components = try(v.monitoring_components, ["SYSTEM_COMPONENTS"])

      # Node Service Account
      create_service_account = try(v.create_service_account, true)
      node_service_account   = try(v.node_service_account, null)

      # Raw Node Pools (for Standard Clusters only)
      raw_node_pools = try(v.node_pools, {})
    }
  }

  # Clusters that provided an external KMS key and want GKE robot IAM role granted
  clusters_with_kms = {
    for k, v in local.clusters : k => v
    if v.enable_database_encryption && v.database_encryption_key != null && v.grant_kms_iam
  }

  # ----------------------------------------------------------------------------
  # 3. GKE Node Pools (Flattened for Standard Clusters)
  # ----------------------------------------------------------------------------
  standard_clusters = {
    for k, v in local.clusters : k => v
    if v.mode == "STANDARD"
  }

  node_pools = merge([
    for cluster_key, cluster in local.standard_clusters : {
      for pool_key, pool in cluster.raw_node_pools : "${cluster.name}/${try(pool.name, tostring(pool_key))}" => {
        cluster_key  = cluster_key
        cluster_name = cluster.name
        project_id   = cluster.project_id
        location     = cluster.location
        name         = try(pool.name, tostring(pool_key))

        # Node Compute Configuration
        machine_type = try(pool.machine_type, "e2-medium")
        disk_size_gb = tonumber(try(pool.disk_size_gb, 30))
        disk_type    = try(pool.disk_type, "pd-balanced")
        spot         = try(pool.spot, false)
        preemptible  = try(pool.preemptible, false)

        # Capacity & Autoscaling
        initial_node_count = tonumber(try(pool.initial_node_count, 1))
        autoscaling = try(pool.autoscaling, null) != null ? {
          min_node_count       = tonumber(try(pool.autoscaling.min_node_count, 1))
          max_node_count       = tonumber(try(pool.autoscaling.max_node_count, 3))
          total_min_node_count = try(pool.autoscaling.total_min_node_count, null)
          total_max_node_count = try(pool.autoscaling.total_max_node_count, null)
        } : null

        # Management
        auto_repair  = try(pool.management.auto_repair, true)
        auto_upgrade = try(pool.management.auto_upgrade, true)

        # Security
        enable_secure_boot          = try(pool.shielded_instance_config.enable_secure_boot, true)
        enable_integrity_monitoring = try(pool.shielded_instance_config.enable_integrity_monitoring, true)

        # Metadata & Orchestration
        labels = merge(cluster.labels, try(pool.labels, {}))
        tags   = try(pool.tags, ["gke-node", "${cluster.name}-node"])
        taints = try(pool.taints, [])
      }
    }
  ]...)

  # ----------------------------------------------------------------------------
  # 4. GKE Ingress, Gateway API & NEG Configurations
  # ----------------------------------------------------------------------------
  raw_ingress_gateways = try(local.cfg.ingress_gateways, try(local.cfg.gke_ingress_gateways, {}))

  # 4a. Static IP Reservations for Ingress & Gateway API
  gateway_ip_reservations = {
    for k, v in try(local.raw_ingress_gateways.ip_reservations, {}) : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      description = try(v.description, "Static IP reservation for GKE Gateway/Ingress ${try(v.name, tostring(k))}")
      type        = upper(try(v.type, "GLOBAL_EXTERNAL")) # "GLOBAL_EXTERNAL", "REGIONAL_EXTERNAL", "REGIONAL_INTERNAL"
      region      = try(v.region, local.default_region)
      subnetwork  = try(v.subnetwork, local.default_subnetwork)
      address     = try(v.address, null)
      labels      = merge(local.global_tags, try(v.labels, {}))
    }
  }

  global_gateway_ips = {
    for k, v in local.gateway_ip_reservations : k => v
    if v.type == "GLOBAL_EXTERNAL"
  }

  regional_gateway_ips = {
    for k, v in local.gateway_ip_reservations : k => v
    if v.type != "GLOBAL_EXTERNAL"
  }

  # 4b. Standalone Network Endpoint Groups (NEGs)
  standalone_negs = {
    for k, v in try(local.raw_ingress_gateways.standalone_negs, {}) : try(v.name, tostring(k)) => {
      name                  = try(v.name, tostring(k))
      project_id            = try(v.project_id, local.default_project_id)
      zone                  = try(v.zone, "${local.default_region}-a")
      network               = try(v.network, local.default_network)
      subnetwork            = try(v.subnetwork, local.default_subnetwork)
      network_endpoint_type = upper(try(v.network_endpoint_type, "GCE_VM_IP_PORT")) # GCE_VM_IP_PORT, NON_GCP_PRIVATE_IP_PORT
      default_port          = try(v.default_port, 80)
      description           = try(v.description, "Standalone NEG for GKE load balancing")
    }
  }

  # 4c. Google Managed SSL Certificates (for Gateway API / Ingress)
  managed_ssl_certificates = {
    for k, v in try(local.raw_ingress_gateways.ssl_certificates, {}) : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      description = try(v.description, "Managed SSL Certificate for GKE Gateway ${try(v.name, tostring(k))}")
      domains     = try(v.domains, [])
    }
  }

  # ----------------------------------------------------------------------------
  # 5. Secrets and Workload Identity Integration (Referencing External Secrets)
  # ----------------------------------------------------------------------------
  raw_secrets_config = try(local.cfg.secrets_and_config, try(local.cfg.secrets_config, {}))

  # Workload access to existing Secret Manager secrets
  raw_sm_access = try(local.raw_secrets_config.secret_manager_access, [])

  secret_workload_access_bindings = [
    for item in local.raw_sm_access : {
      key             = "${item.secret_id}-${item.namespace}-${item.service_account}"
      secret_id       = item.secret_id
      project_id      = try(item.project_id, local.default_project_id)
      namespace       = item.namespace
      service_account = item.service_account
    }
  ]

  # Dedicated Workload Service Accounts (GSA <-> KSA mapping)
  raw_workload_sas = try(local.raw_secrets_config.workload_service_accounts, {})

  workload_service_accounts = {
    for k, v in local.raw_workload_sas : try(v.account_id, tostring(k)) => {
      account_id   = try(v.account_id, tostring(k))
      project_id   = try(v.project_id, local.default_project_id)
      display_name = try(v.display_name, "Workload SA for ${try(v.account_id, tostring(k))}")
      description  = try(v.description, "GCP Service Account for GKE Workload Identity")
      roles        = try(v.roles, ["roles/secretmanager.secretAccessor"])
      k8s_bindings = try(v.k8s_bindings, [])
    }
  }

  workload_sa_project_roles = flatten([
    for sa_key, sa in local.workload_service_accounts : [
      for role in sa.roles : {
        key        = "${sa_key}-${role}"
        sa_key     = sa_key
        project_id = sa.project_id
        role       = role
      }
    ]
  ])

  workload_sa_k8s_bindings = flatten([
    for sa_key, sa in local.workload_service_accounts : [
      for binding in sa.k8s_bindings : {
        key             = "${sa_key}-${binding.namespace}-${binding.service_account}"
        sa_key          = sa_key
        project_id      = sa.project_id
        namespace       = binding.namespace
        service_account = binding.service_account
      }
    ]
  ])
}
