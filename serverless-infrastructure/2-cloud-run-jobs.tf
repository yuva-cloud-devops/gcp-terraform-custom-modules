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
# 1. Dedicated Service Accounts for Cloud Run Jobs
# ------------------------------------------------------------------------------
resource "google_service_account" "job_sa" {
  for_each = {
    for k, v in local.cloud_run_jobs : k => v
    if v.create_sa
  }

  project      = each.value.project_id
  account_id   = substr("job-${each.value.name}", 0, 30)
  display_name = "Cloud Run Job SA for ${each.value.name}"
  description  = "Dedicated runtime service account for batch job ${each.value.name}"
}

# ------------------------------------------------------------------------------
# 2. Cloud Run v2 Jobs (Batch Tasks, Run-to-Completion, DB Migrations)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "jobs" {
  for_each = local.cloud_run_jobs

  name                = each.value.name
  project             = each.value.project_id
  location            = each.value.location
  labels              = each.value.labels
  deletion_protection = each.value.deletion_protection

  template {
    task_count  = each.value.task_count
    parallelism = each.value.parallelism

    template {
      timeout         = each.value.timeout
      max_retries     = each.value.max_retries
      service_account = each.value.create_sa ? google_service_account.job_sa[each.key].email : each.value.service_account

      containers {
        image   = each.value.image
        command = each.value.command
        args    = each.value.args

        resources {
          limits = {
            cpu    = each.value.cpu_limit
            memory = each.value.memory_limit
          }
        }

        # Plaintext Environment Variables
        dynamic "env" {
          for_each = each.value.env_vars
          content {
            name  = env.key
            value = tostring(env.value)
          }
        }

        # Secret Environment Variables
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

      # Modern Recommended: Direct VPC Egress (Access Private Cloud SQL / Redis)
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
  }
}
