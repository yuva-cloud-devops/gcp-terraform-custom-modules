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
# 1. Cloud Tasks Queues (Rate-Limited Asynchronous Execution)
# ------------------------------------------------------------------------------
resource "google_cloud_tasks_queue" "queues" {
  for_each = local.cloud_tasks_queues

  name     = each.value.name
  project  = each.value.project_id
  location = each.value.location

  rate_limits {
    max_dispatches_per_second = each.value.max_dispatches_per_second
    max_concurrent_dispatches = each.value.max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = each.value.max_attempts
    max_retry_duration = each.value.max_retry_duration
    min_backoff        = each.value.min_backoff
    max_backoff        = each.value.max_backoff
    max_doublings      = each.value.max_doublings
  }
}

# ------------------------------------------------------------------------------
# 2. Cloud Scheduler Jobs (Cron Triggers for Internal & External Endpoints)
# ------------------------------------------------------------------------------
resource "google_cloud_scheduler_job" "jobs" {
  for_each = local.cloud_scheduler_jobs

  name             = each.value.name
  project          = each.value.project_id
  region           = each.value.region
  description      = each.value.description
  schedule         = each.value.schedule
  time_zone        = each.value.time_zone
  paused           = each.value.paused
  attempt_deadline = each.value.attempt_deadline

  dynamic "http_target" {
    for_each = each.value.http_target != null ? [each.value.http_target] : []
    content {
      uri         = http_target.value.uri
      http_method = http_target.value.http_method
      body        = http_target.value.body
      headers     = http_target.value.headers

      dynamic "oidc_token" {
        for_each = http_target.value.oidc_token != null ? [http_target.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience              = try(oidc_token.value.audience, http_target.value.uri)
        }
      }
    }
  }

  dynamic "pubsub_target" {
    for_each = each.value.pubsub_target != null ? [each.value.pubsub_target] : []
    content {
      topic_name = pubsub_target.value.topic_name
      data       = pubsub_target.value.data
      attributes = pubsub_target.value.attributes
    }
  }
}
