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
# 1. Dedicated Service Accounts for 2nd Gen Cloud Functions
# ------------------------------------------------------------------------------
resource "google_service_account" "function_sa" {
  for_each = {
    for k, v in local.cloud_functions : k => v
    if v.create_sa
  }

  project      = each.value.project_id
  account_id   = substr("fn-${each.value.name}", 0, 30)
  display_name = "Cloud Function SA for ${each.value.name}"
  description  = "Dedicated runtime service account for 2nd gen function ${each.value.name}"
}

# ------------------------------------------------------------------------------
# 2. Cloud Functions (2nd Gen - Powered by Cloud Run)
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "functions" {
  provider = google-beta
  for_each = local.cloud_functions

  name        = each.value.name
  project     = each.value.project_id
  location    = each.value.location
  description = each.value.description
  labels      = each.value.labels

  build_config {
    runtime     = each.value.runtime
    entry_point = each.value.entry_point

    dynamic "source" {
      for_each = each.value.source_archive_bucket != null ? [1] : []
      content {
        storage_source {
          bucket = each.value.source_archive_bucket
          object = each.value.source_archive_object
        }
      }
    }
  }

  service_config {
    max_instance_count    = each.value.max_instances
    min_instance_count    = each.value.min_instances
    available_memory      = each.value.available_memory
    timeout_seconds       = each.value.timeout_seconds
    service_account_email = each.value.create_sa ? google_service_account.function_sa[each.key].email : each.value.service_account

    # Ingress Isolation: ALLOW_ALL (External), ALLOW_INTERNAL_ONLY, ALLOW_INTERNAL_AND_GCLB
    ingress_settings = each.value.ingress

    # Plaintext Environment Variables
    environment_variables = each.value.env_vars

    # Secret Environment Variables
    dynamic "secret_environment_variables" {
      for_each = each.value.secret_envs
      content {
        key        = secret_environment_variables.value.name
        project_id = try(secret_environment_variables.value.project_id, each.value.project_id)
        secret     = secret_environment_variables.value.secret_id
        version    = try(secret_environment_variables.value.version, "latest")
      }
    }

    # VPC Access
    vpc_connector                 = each.value.vpc_connector
    vpc_connector_egress_settings = each.value.vpc_connector != null ? each.value.vpc_egress_mode : null
  }

  # Optional Eventarc / PubSub Event Trigger
  dynamic "event_trigger" {
    for_each = each.value.event_trigger != null ? [each.value.event_trigger] : []
    content {
      trigger_region        = try(event_trigger.value.trigger_region, each.value.location)
      event_type            = try(event_trigger.value.event_type, "google.cloud.pubsub.topic.v1.messagePublished")
      pubsub_topic          = try(event_trigger.value.pubsub_topic, null)
      retry_policy          = try(event_trigger.value.retry_policy, "RETRY_POLICY_DO_NOT_RETRY")
      service_account_email = try(event_trigger.value.service_account_email, null)
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Cloud Function Invocation Permissions
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function_iam_member" "invokers" {
  for_each = {
    for item in local.function_invokers : item.key => item
  }

  project        = each.value.project_id
  location       = each.value.location
  cloud_function = google_cloudfunctions2_function.functions[each.value.fn_key].name
  role           = "roles/cloudfunctions.invoker"
  member         = each.value.member
}
