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
# 1. Dedicated Service Accounts for Cloud Run Services
# ------------------------------------------------------------------------------
resource "google_service_account" "service_sa" {
  for_each = {
    for k, v in local.cloud_run_services : k => v
    if v.create_sa
  }

  project      = each.value.project_id
  account_id   = substr("run-${each.value.name}", 0, 30)
  display_name = "Cloud Run SA for ${each.value.name}"
  description  = "Dedicated runtime service account for Cloud Run service ${each.value.name}"
}

# ------------------------------------------------------------------------------
# 2. Cloud Run v2 Services (HTTP APIs, Webhooks, Microservices)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "services" {
  for_each = local.cloud_run_services

  name        = each.value.name
  project     = each.value.project_id
  location    = each.value.location
  description = each.value.description
  labels      = each.value.labels

  # Ingress Controls: INGRESS_TRAFFIC_ALL (Public), INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
  ingress             = each.value.ingress
  deletion_protection = each.value.deletion_protection

  template {
    service_account                  = each.value.create_sa ? google_service_account.service_sa[each.key].email : each.value.service_account
    timeout                          = each.value.timeout
    max_instance_request_concurrency = each.value.concurrency

    scaling {
      min_instance_count = each.value.min_instances
      max_instance_count = each.value.max_instances
    }

    containers {
      image   = each.value.image
      command = each.value.command
      args    = each.value.args

      ports {
        container_port = each.value.port
      }

      resources {
        limits = {
          cpu    = each.value.cpu_limit
          memory = each.value.memory_limit
        }
        cpu_idle          = each.value.cpu_idle
        startup_cpu_boost = each.value.startup_cpu_boost
      }

      # Plaintext Environment Variables
      dynamic "env" {
        for_each = each.value.env_vars
        content {
          name  = env.key
          value = tostring(env.value)
        }
      }

      # Secret Environment Variables (Secret Manager Integration)
      dynamic "env" {
        for_each = each.value.secret_envs
        content {
          name = env.value.name
          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = try(env.value.version, "latest")
            }
          }
        }
      }

      # Secret Volume Mounts
      dynamic "volume_mounts" {
        for_each = each.value.secret_volumes
        content {
          name       = volume_mounts.value.name
          mount_path = volume_mounts.value.mount_path
        }
      }
    }

    # Secret Volumes definition
    dynamic "volumes" {
      for_each = each.value.secret_volumes
      content {
        name = volumes.value.name
        secret {
          secret = volumes.value.secret_id
          dynamic "items" {
            for_each = try(volumes.value.items, [])
            content {
              path    = items.value.path
              version = try(items.value.version, "latest")
            }
          }
        }
      }
    }

    # Modern Recommended: Direct VPC Egress (Zero Connector VMs, up to 100 Gbps)
    dynamic "vpc_access" {
      for_each = each.value.enable_direct_vpc && each.value.vpc_subnetwork != null ? [1] : []
      content {
        network_interfaces {
          subnetwork = each.value.vpc_subnetwork
          network    = each.value.vpc_network
          tags       = length(each.value.vpc_network_tags) > 0 ? each.value.vpc_network_tags : null
        }
        egress = each.value.vpc_egress_mode
      }
    }
  }

  # Traffic Allocation
  dynamic "traffic" {
    for_each = each.value.traffic
    content {
      type     = try(traffic.value.type, "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST")
      percent  = try(traffic.value.percent, 100)
      revision = try(traffic.value.revision, null)
      tag      = try(traffic.value.tag, null)
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Invocation IAM Policies (Public / Unauthenticated vs Private / Internal)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = {
    for item in local.cloud_run_invokers : item.key => item
  }

  project  = each.value.project_id
  location = each.value.location
  name     = google_cloud_run_v2_service.services[each.value.svc_key].name
  role     = "roles/run.invoker"
  member   = each.value.member
}
