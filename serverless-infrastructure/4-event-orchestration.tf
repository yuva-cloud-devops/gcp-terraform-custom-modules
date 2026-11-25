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
# 1. Cloud Workflows (Serverless State Machines)
# ------------------------------------------------------------------------------
resource "google_service_account" "workflow_sa" {
  for_each = {
    for k, v in local.cloud_workflows : k => v
    if v.create_sa
  }

  project      = each.value.project_id
  account_id   = substr("wf-${each.value.name}", 0, 30)
  display_name = "Cloud Workflows SA for ${each.value.name}"
  description  = "Dedicated execution service account for Cloud Workflow ${each.value.name}"
}

resource "google_workflows_workflow" "workflows" {
  for_each = local.cloud_workflows

  name            = each.value.name
  project         = each.value.project_id
  region          = each.value.region
  description     = each.value.description
  labels          = each.value.labels
  service_account = each.value.create_sa ? google_service_account.workflow_sa[each.key].email : each.value.service_account

  source_contents = each.value.source_contents != null ? each.value.source_contents : <<-EOF
    # Placeholder workflow definition
    main:
      steps:
        - init:
            assign:
              - status: "INITIALIZED"
        - complete:
            return: $${status}
  EOF
}

# ------------------------------------------------------------------------------
# 2. Eventarc Triggers (Decoupled Event Router for Cloud Run / Workflows)
# ------------------------------------------------------------------------------
resource "google_eventarc_trigger" "triggers" {
  for_each = local.eventarc_triggers

  name     = each.value.name
  project  = each.value.project_id
  location = each.value.location
  labels   = each.value.labels

  dynamic "matching_criteria" {
    for_each = each.value.event_filters
    content {
      attribute = matching_criteria.value.attribute
      value     = matching_criteria.value.value
      operator  = matching_criteria.value.operator
    }
  }

  destination {
    dynamic "cloud_run_service" {
      for_each = each.value.destination_run_service != null ? [1] : []
      content {
        service = each.value.destination_run_service
        path    = each.value.destination_run_path
        region  = each.value.location
      }
    }

    workflow = each.value.destination_workflow
  }

  service_account = each.value.service_account
}
