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
# 1. Artifact Registry Outputs
# ------------------------------------------------------------------------------
output "artifact_registries" {
  description = "Detailed map of all created Artifact Registry repositories."
  value = {
    for k, repo in google_artifact_registry_repository.registries : k => {
      id             = repo.id
      name           = repo.repository_id
      format         = repo.format
      location       = repo.location
      project        = repo.project
      repository_url = "${repo.location}-docker.pkg.dev/${repo.project}/${repo.repository_id}"
    }
  }
}

# ------------------------------------------------------------------------------
# 2. GKE Cluster Outputs
# ------------------------------------------------------------------------------
output "gke_clusters" {
  description = "Detailed map of GKE clusters (Standard and Autopilot)."
  sensitive   = false
  value = {
    for k, cluster in google_container_cluster.clusters : k => {
      id                          = cluster.id
      name                        = cluster.name
      location                    = cluster.location
      project                     = cluster.project
      mode                        = local.clusters[k].mode
      endpoint                    = cluster.endpoint
      master_version              = cluster.master_version
      gateway_api_channel         = local.clusters[k].gateway_api_channel
      http_load_balancing_enabled = local.clusters[k].http_load_balancing
      database_encryption_state   = local.clusters[k].enable_database_encryption ? "ENCRYPTED" : "DECRYPTED"
      database_encryption_key     = local.clusters[k].database_encryption_key
      secret_manager_addon        = local.clusters[k].secret_manager_addon
      workload_identity_pool      = local.clusters[k].workload_identity ? "${cluster.project}.svc.id.goog" : null
      node_service_account        = try(google_service_account.gke_nodes[k].email, local.clusters[k].node_service_account)
      get_credentials_command     = "gcloud container clusters get-credentials ${cluster.name} --region ${cluster.location} --project ${cluster.project}"
    }
  }
}

output "gke_cluster_ca_certificates" {
  description = "Map of cluster CA certificates (base64 encoded) for Kubernetes / Helm provider configurations."
  sensitive   = true
  value = {
    for k, cluster in google_container_cluster.clusters : k => cluster.master_auth[0].cluster_ca_certificate
  }
}

# ------------------------------------------------------------------------------
# 3. GKE Node Pools Outputs
# ------------------------------------------------------------------------------
output "gke_node_pools" {
  description = "Map of managed GKE Node Pools."
  value = {
    for k, pool in google_container_node_pool.pools : k => {
      id           = pool.id
      name         = pool.name
      cluster      = pool.cluster
      location     = pool.location
      node_count   = pool.node_count
      machine_type = pool.node_config[0].machine_type
      spot         = pool.node_config[0].spot
    }
  }
}

# ------------------------------------------------------------------------------
# 4. GKE Ingress & Gateway API Outputs
# ------------------------------------------------------------------------------
output "gateway_ip_reservations" {
  description = "Map of static IP reservations for GKE Gateway API and Ingress."
  value = merge(
    {
      for k, ip in google_compute_global_address.gateway_ips : k => {
        name         = ip.name
        type         = "GLOBAL_EXTERNAL"
        address      = ip.address
        self_link    = ip.self_link
        gateway_hint = "Reference in Gateway via addresses: [{ type: NamedAddress, value: \"${ip.name}\" }]"
      }
    },
    {
      for k, ip in google_compute_address.gateway_ips : k => {
        name         = ip.name
        type         = ip.address_type
        address      = ip.address
        region       = ip.region
        self_link    = ip.self_link
        gateway_hint = "Reference in Gateway via addresses: [{ type: NamedAddress, value: \"${ip.name}\" }]"
      }
    }
  )
}

output "standalone_negs" {
  description = "Map of standalone Network Endpoint Groups (NEGs) for Cloud Load Balancing."
  value = {
    for k, neg in google_compute_network_endpoint_group.negs : k => {
      id                    = neg.id
      name                  = neg.name
      zone                  = neg.zone
      network_endpoint_type = neg.network_endpoint_type
      self_link             = neg.self_link
    }
  }
}

output "managed_ssl_certificates" {
  description = "Map of Google-managed SSL Certificates for GKE Gateway / Ingress."
  value = {
    for k, cert in google_compute_managed_ssl_certificate.gateway_certs : k => {
      id          = cert.id
      name        = cert.name
      domains     = cert.managed[0].domains
      certificate = cert.certificate_id
    }
  }
}

# ------------------------------------------------------------------------------
# 5. Secrets & Workload Identity Outputs
# ------------------------------------------------------------------------------
output "workload_service_accounts" {
  description = "Map of dedicated Workload Identity Service Accounts."
  value = {
    for k, sa in google_service_account.workload_sas : k => {
      id           = sa.id
      email        = sa.email
      account_id   = sa.account_id
      k8s_bindings = [for b in local.workload_sa_k8s_bindings : "${b.namespace}/${b.service_account}" if b.sa_key == k]
    }
  }
}

# ------------------------------------------------------------------------------
# 6. Summary Output
# ------------------------------------------------------------------------------
output "container_summary" {
  description = "Executive summary of container infrastructure provisioned."
  value = {
    total_artifact_registries       = length(google_artifact_registry_repository.registries)
    total_gke_clusters              = length(google_container_cluster.clusters)
    total_standard_node_pools       = length(google_container_node_pool.pools)
    total_gateway_ip_reservations   = length(google_compute_global_address.gateway_ips) + length(google_compute_address.gateway_ips)
    total_standalone_negs           = length(google_compute_network_endpoint_group.negs)
    total_workload_service_accounts = length(google_service_account.workload_sas)
    clusters = [
      for k, c in local.clusters : {
        name                      = c.name
        mode                      = c.mode
        location                  = c.location
        gateway_api_channel       = c.gateway_api_channel
        database_encryption_state = c.enable_database_encryption ? "ENCRYPTED" : "DECRYPTED"
        secret_manager_addon      = c.secret_manager_addon
        node_pools                = [for pk, p in local.node_pools : p.name if p.cluster_key == k]
      }
    ]
  }
}
