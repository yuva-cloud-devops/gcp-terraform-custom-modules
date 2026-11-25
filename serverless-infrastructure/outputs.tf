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
# 1. Cloud Run Services Outputs
# ------------------------------------------------------------------------------
output "cloud_run_services" {
  description = "Detailed map of created Cloud Run services including endpoint URIs, ingress policy, and VPC access."
  value = {
    for k, svc in google_cloud_run_v2_service.services : k => {
      id                        = svc.id
      name                      = svc.name
      location                  = svc.location
      uri                       = svc.uri
      ingress                   = svc.ingress
      service_account           = svc.template[0].service_account
      direct_vpc_egress_enabled = length(svc.template[0].vpc_access[0].network_interfaces) > 0
      vpc_egress_mode           = svc.template[0].vpc_access[0].egress
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Cloud Run Jobs Outputs
# ------------------------------------------------------------------------------
output "cloud_run_jobs" {
  description = "Detailed map of created Cloud Run batch jobs."
  value = {
    for k, job in google_cloud_run_v2_job.jobs : k => {
      id                        = job.id
      name                      = job.name
      location                  = job.location
      service_account           = job.template[0].template[0].service_account
      task_count                = job.template[0].task_count
      parallelism               = job.template[0].parallelism
      direct_vpc_egress_enabled = length(job.template[0].template[0].vpc_access[0].network_interfaces) > 0
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Cloud Functions (2nd Gen) Outputs
# ------------------------------------------------------------------------------
output "cloud_functions" {
  description = "Detailed map of created 2nd gen Cloud Functions."
  value = {
    for k, fn in google_cloudfunctions2_function.functions : k => {
      id               = fn.id
      name             = fn.name
      location         = fn.location
      uri              = fn.url
      ingress_settings = fn.service_config[0].ingress_settings
      service_account  = fn.service_config[0].service_account_email
      runtime          = fn.build_config[0].runtime
    }
  }
}

# ------------------------------------------------------------------------------
# 4. Cloud Workflows Outputs
# ------------------------------------------------------------------------------
output "cloud_workflows" {
  description = "Map of created Cloud Workflows."
  value = {
    for k, wf in google_workflows_workflow.workflows : k => {
      id              = wf.id
      name            = wf.name
      region          = wf.region
      service_account = wf.service_account
      state           = wf.state
    }
  }
}

# ------------------------------------------------------------------------------
# 5. Eventarc Triggers Outputs
# ------------------------------------------------------------------------------
output "eventarc_triggers" {
  description = "Map of created Eventarc event triggers."
  value = {
    for k, tr in google_eventarc_trigger.triggers : k => {
      id       = tr.id
      name     = tr.name
      location = tr.location
    }
  }
}

# ------------------------------------------------------------------------------
# 6. Async Queues & Scheduler Outputs
# ------------------------------------------------------------------------------
output "cloud_tasks_queues" {
  description = "Map of created Cloud Tasks queues."
  value = {
    for k, q in google_cloud_tasks_queue.queues : k => {
      id       = q.id
      name     = q.name
      location = q.location
    }
  }
}

output "cloud_scheduler_jobs" {
  description = "Map of created Cloud Scheduler jobs."
  value = {
    for k, job in google_cloud_scheduler_job.jobs : k => {
      id       = job.id
      name     = job.name
      region   = job.region
      schedule = job.schedule
      paused   = job.paused
    }
  }
}

output "cloud_run_domain_mappings" {
  description = "Detailed map of Cloud Run custom domain mappings and required DNS records."
  value = {
    for k, dm in google_cloud_run_domain_mapping.domain_mappings : k => {
      id               = dm.id
      domain           = dm.name
      service          = dm.spec[0].route_name
      resource_records = try(dm.status[0].resource_records, [])
    }
  }
}

# ------------------------------------------------------------------------------
# 7. Summary Output
# ------------------------------------------------------------------------------
output "serverless_summary" {
  description = "Overview summary of provisioned serverless resources."
  value = {
    cloud_run_services_count   = length(google_cloud_run_v2_service.services)
    cloud_run_jobs_count       = length(google_cloud_run_v2_job.jobs)
    domain_mappings_count      = length(google_cloud_run_domain_mapping.domain_mappings)
    cloud_functions_count      = length(google_cloudfunctions2_function.functions)
    cloud_workflows_count      = length(google_workflows_workflow.workflows)
    eventarc_triggers_count    = length(google_eventarc_trigger.triggers)
    cloud_tasks_queues_count   = length(google_cloud_tasks_queue.queues)
    cloud_scheduler_jobs_count = length(google_cloud_scheduler_job.jobs)
  }
}
