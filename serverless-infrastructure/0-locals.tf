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
  # 0. Configuration Ingestion & Root Validation
  # ----------------------------------------------------------------------------
  raw_config = var.yaml_content != null ? yamldecode(var.yaml_content) : (
    var.config_file_path != null ? yamldecode(file(var.config_file_path)) : {}
  )

  cfg = try(local.raw_config.serverless_infrastructure, local.raw_config)

  # Global Default Context
  default_project_id = try(local.cfg.project_id, null)
  default_region     = try(local.cfg.region, "asia-south1")
  default_network    = try(local.cfg.network, null)
  default_subnetwork = try(local.cfg.subnetwork, null)
  default_tags       = try(local.cfg.tags, {})

  # Global Direct VPC Egress Defaults
  raw_vpc_defaults        = try(local.cfg.vpc_access, {})
  default_vpc_egress_mode = upper(try(local.raw_vpc_defaults.egress_mode, "PRIVATE_RANGES_ONLY")) # PRIVATE_RANGES_ONLY or ALL_TRAFFIC

  # ----------------------------------------------------------------------------
  # 1. Cloud Run Services (v2 API)
  # ----------------------------------------------------------------------------
  raw_services = try(local.cfg.cloud_run_services, {})

  cloud_run_services = {
    for k, v in local.raw_services : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      location    = try(v.location, try(v.region, local.default_region))
      description = try(v.description, "Cloud Run Service ${try(v.name, tostring(k))}")
      labels      = merge(local.default_tags, try(v.labels, {}))

      # Container Image & Execution
      image   = v.image
      command = try(v.command, null)
      args    = try(v.args, null)
      port    = tonumber(try(v.port, 8080))
      timeout = try(v.timeout, "300s")

      # Concurrency & Scaling
      concurrency       = tonumber(try(v.concurrency, 80))
      min_instances     = tonumber(try(v.scaling.min_instances, try(v.min_instances, 0)))
      max_instances     = tonumber(try(v.scaling.max_instances, try(v.max_instances, 10)))
      cpu_idle          = try(v.cpu_idle, true)
      startup_cpu_boost = try(v.startup_cpu_boost, true)

      # Resource Limits & Requests
      cpu_limit      = try(v.resources.limits.cpu, "1")
      memory_limit   = try(v.resources.limits.memory, "512Mi")
      cpu_request    = try(v.resources.requests.cpu, null)
      memory_request = try(v.resources.requests.memory, null)

      # Environment Variables & Secrets
      env_vars       = try(v.env, try(v.env_vars, {}))
      secret_envs    = try(v.secret_envs, [])
      secret_volumes = try(v.secret_volumes, [])

      # Ingress & Network Isolation (Internal vs External)
      # Options: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
      ingress               = upper(try(v.ingress, "INGRESS_TRAFFIC_ALL"))
      allow_unauthenticated = try(v.allow_unauthenticated, false)
      invoker_members       = try(v.invoker_members, [])

      # Direct VPC Egress (Modern 2024+ serverless networking)
      enable_direct_vpc = try(v.direct_vpc_egress.enabled, try(v.enable_vpc_egress, local.default_subnetwork != null))
      vpc_subnetwork    = try(v.direct_vpc_egress.subnetwork, try(v.subnetwork, local.default_subnetwork))
      vpc_network       = try(v.direct_vpc_egress.network, try(v.network, local.default_network))
      vpc_egress_mode   = upper(try(v.direct_vpc_egress.egress_mode, local.default_vpc_egress_mode))
      vpc_network_tags  = try(v.direct_vpc_egress.network_tags, try(v.network_tags, []))

      # Identity & Security
      service_account     = try(v.service_account, null)
      create_sa           = try(v.create_service_account, try(v.service_account, null) == null)
      deletion_protection = try(v.deletion_protection, false)

      # Custom Domain Mappings
      domain_mappings = try(v.domain_mappings, [])

      # Traffic Splitting (Canary / Revisions)
      traffic = try(v.traffic, [
        {
          type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
          percent = 100
        }
      ])
    }
  }

  # Flattened invoker IAM members for Cloud Run Services
  cloud_run_invokers = flatten([
    for svc_key, svc in local.cloud_run_services : [
      for member in(svc.allow_unauthenticated ? ["allUsers"] : svc.invoker_members) : {
        key        = "${svc_key}-${member}"
        svc_key    = svc_key
        service    = svc.name
        project_id = svc.project_id
        location   = svc.location
        member     = member
      }
    ]
  ])

  # Custom Domain Mappings (Supports both root-level domain_mappings and inline service domain_mappings)
  raw_domain_mappings = try(local.cfg.domain_mappings, {})

  domain_mappings = merge(
    {
      for k, v in local.raw_domain_mappings : try(v.domain, try(v.name, tostring(k))) => {
        domain           = try(v.domain, try(v.name, tostring(k)))
        service_name     = v.service
        location         = try(v.location, try(v.region, local.default_region))
        project_id       = try(v.project_id, local.default_project_id)
        force_override   = try(v.force_override, false)
        certificate_mode = try(v.certificate_mode, "AUTOMATIC")
      }
    },
    {
      for item in flatten([
        for svc_key, svc in local.cloud_run_services : [
          for d in svc.domain_mappings : {
            key              = try(d.domain, tostring(d))
            domain           = try(d.domain, tostring(d))
            service_name     = svc.name
            location         = svc.location
            project_id       = svc.project_id
            force_override   = try(d.force_override, false)
            certificate_mode = try(d.certificate_mode, "AUTOMATIC")
          }
        ]
      ]) : item.key => item
    }
  )

  # ----------------------------------------------------------------------------
  # 2. Cloud Run Jobs (v2 API for Batch / DB Migrations)
  # ----------------------------------------------------------------------------
  raw_jobs = try(local.cfg.cloud_run_jobs, {})

  cloud_run_jobs = {
    for k, v in local.raw_jobs : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      location    = try(v.location, try(v.region, local.default_region))
      description = try(v.description, "Cloud Run Job ${try(v.name, tostring(k))}")
      labels      = merge(local.default_tags, try(v.labels, {}))

      # Container Image & Execution
      image   = v.image
      command = try(v.command, null)
      args    = try(v.args, null)

      # Job Execution Parameters
      task_count  = tonumber(try(v.task_count, 1))
      parallelism = tonumber(try(v.parallelism, 1))
      max_retries = tonumber(try(v.max_retries, 3))
      timeout     = try(v.timeout, "600s")

      # Resource Limits & Requests
      cpu_limit    = try(v.resources.limits.cpu, "1")
      memory_limit = try(v.resources.limits.memory, "512Mi")

      # Environment Variables & Secrets
      env_vars       = try(v.env, try(v.env_vars, {}))
      secret_envs    = try(v.secret_envs, [])
      secret_volumes = try(v.secret_volumes, [])

      # Direct VPC Egress (Access to Private Cloud SQL / Redis)
      enable_direct_vpc = try(v.direct_vpc_egress.enabled, try(v.enable_vpc_egress, local.default_subnetwork != null))
      vpc_subnetwork    = try(v.direct_vpc_egress.subnetwork, try(v.subnetwork, local.default_subnetwork))
      vpc_network       = try(v.direct_vpc_egress.network, try(v.network, local.default_network))
      vpc_egress_mode   = upper(try(v.direct_vpc_egress.egress_mode, local.default_vpc_egress_mode))
      vpc_network_tags  = try(v.direct_vpc_egress.network_tags, try(v.network_tags, []))

      # Identity & Protection
      service_account     = try(v.service_account, null)
      create_sa           = try(v.create_service_account, try(v.service_account, null) == null)
      deletion_protection = try(v.deletion_protection, false)
    }
  }

  # ----------------------------------------------------------------------------
  # 3. Cloud Functions (2nd Gen API)
  # ----------------------------------------------------------------------------
  raw_functions = try(local.cfg.cloud_functions, {})

  cloud_functions = {
    for k, v in local.raw_functions : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      location    = try(v.location, try(v.region, local.default_region))
      description = try(v.description, "2nd Gen Cloud Function ${try(v.name, tostring(k))}")
      labels      = merge(local.default_tags, try(v.labels, {}))

      # Build Configuration
      runtime               = try(v.runtime, "nodejs20")
      entry_point           = try(v.entry_point, "main")
      source_archive_bucket = try(v.source_archive_bucket, null)
      source_archive_object = try(v.source_archive_object, null)

      # Ingress & External/Internal Controls
      # ALLOW_ALL, ALLOW_INTERNAL_ONLY, ALLOW_INTERNAL_AND_GCLB
      ingress               = upper(try(v.ingress, "ALLOW_ALL"))
      allow_unauthenticated = try(v.allow_unauthenticated, false)
      invoker_members       = try(v.invoker_members, [])

      # VPC Access
      vpc_connector   = try(v.vpc_connector, try(v.direct_vpc_egress.subnetwork, null))
      vpc_egress_mode = upper(try(v.vpc_connector_egress_settings, try(v.direct_vpc_egress.egress_mode, "PRIVATE_RANGES_ONLY")))

      # Compute & Scaling
      available_memory = try(v.available_memory, "256M")
      timeout_seconds  = tonumber(try(v.timeout_seconds, 60))
      min_instances    = tonumber(try(v.min_instances, 0))
      max_instances    = tonumber(try(v.max_instances, 5))
      env_vars         = try(v.env, try(v.env_vars, {}))
      secret_envs      = try(v.secret_envs, [])

      # Event Trigger (Optional Pub/Sub or Eventarc event)
      event_trigger = try(v.event_trigger, null)

      # Identity
      service_account = try(v.service_account, null)
      create_sa       = try(v.create_service_account, try(v.service_account, null) == null)
    }
  }

  # Flattened invokers for 2nd Gen Functions (invoker role on underlying Cloud Run service)
  function_invokers = flatten([
    for fn_key, fn in local.cloud_functions : [
      for member in(fn.allow_unauthenticated ? ["allUsers"] : fn.invoker_members) : {
        key        = "${fn_key}-${member}"
        fn_key     = fn_key
        service    = fn.name
        project_id = fn.project_id
        location   = fn.location
        member     = member
      }
    ]
  ])

  # ----------------------------------------------------------------------------
  # 4. Event Orchestration (Eventarc Triggers & Cloud Workflows)
  # ----------------------------------------------------------------------------
  raw_eventarc = try(local.cfg.eventarc_triggers, {})

  eventarc_triggers = {
    for k, v in local.raw_eventarc : try(v.name, tostring(k)) => {
      name       = try(v.name, tostring(k))
      project_id = try(v.project_id, local.default_project_id)
      location   = try(v.location, try(v.region, local.default_region))
      labels     = merge(local.default_tags, try(v.labels, {}))

      # Event Matching Criteria
      event_filters = [
        for f in try(v.event_filters, []) : {
          attribute = f.attribute
          value     = f.value
          operator  = try(f.operator, null)
        }
      ]

      # Destination Type (Cloud Run Service or Workflow)
      destination_run_service = try(v.destination.cloud_run_service, null)
      destination_run_path    = try(v.destination.path, "/")
      destination_workflow    = try(v.destination.workflow, null)

      service_account = try(v.service_account, null)
    }
  }

  raw_workflows = try(local.cfg.cloud_workflows, {})

  cloud_workflows = {
    for k, v in local.raw_workflows : try(v.name, tostring(k)) => {
      name            = try(v.name, tostring(k))
      project_id      = try(v.project_id, local.default_project_id)
      region          = try(v.region, local.default_region)
      description     = try(v.description, "Orchestration workflow ${try(v.name, tostring(k))}")
      labels          = merge(local.default_tags, try(v.labels, {}))
      source_contents = try(v.source_contents, null)
      service_account = try(v.service_account, null)
      create_sa       = try(v.create_service_account, try(v.service_account, null) == null)
    }
  }

  # ----------------------------------------------------------------------------
  # 5. Async Queues & Scheduler (Cloud Tasks & Cloud Scheduler)
  # ----------------------------------------------------------------------------
  raw_tasks_queues = try(local.cfg.cloud_tasks_queues, {})

  cloud_tasks_queues = {
    for k, v in local.raw_tasks_queues : try(v.name, tostring(k)) => {
      name       = try(v.name, tostring(k))
      project_id = try(v.project_id, local.default_project_id)
      location   = try(v.location, try(v.region, local.default_region))

      # Rate Limiting
      max_dispatches_per_second = tonumber(try(v.rate_limits.max_dispatches_per_second, try(v.max_dispatches_per_second, 50)))
      max_concurrent_dispatches = tonumber(try(v.rate_limits.max_concurrent_dispatches, try(v.max_concurrent_dispatches, 10)))
      max_burst_size            = tonumber(try(v.rate_limits.max_burst_size, try(v.max_burst_size, 100)))

      # Retry Parameters
      max_attempts       = tonumber(try(v.retry_config.max_attempts, try(v.max_attempts, 5)))
      max_retry_duration = try(v.retry_config.max_retry_duration, try(v.max_retry_duration, "86400s"))
      min_backoff        = try(v.retry_config.min_backoff, try(v.min_backoff, "0.100s"))
      max_backoff        = try(v.retry_config.max_backoff, try(v.max_backoff, "3600s"))
      max_doublings      = tonumber(try(v.retry_config.max_doublings, try(v.max_doublings, 16)))
    }
  }

  raw_scheduler_jobs = try(local.cfg.cloud_scheduler_jobs, {})

  cloud_scheduler_jobs = {
    for k, v in local.raw_scheduler_jobs : try(v.name, tostring(k)) => {
      name             = try(v.name, tostring(k))
      project_id       = try(v.project_id, local.default_project_id)
      region           = try(v.region, local.default_region)
      description      = try(v.description, "Scheduled Cron Job ${try(v.name, tostring(k))}")
      schedule         = try(v.schedule, "0 0 * * *")
      time_zone        = try(v.time_zone, "UTC")
      paused           = try(v.paused, false)
      attempt_deadline = try(v.attempt_deadline, "320s")

      # HTTP Target (calling internal or external endpoints)
      http_target = try(v.http_target, null) != null ? {
        uri         = v.http_target.uri
        http_method = upper(try(v.http_target.http_method, "POST"))
        body        = try(v.http_target.body, null) != null ? base64encode(v.http_target.body) : null
        headers     = try(v.http_target.headers, { "Content-Type" = "application/json" })
        oidc_token  = try(v.http_target.oidc_token, null)
      } : null

      # Pub/Sub Target
      pubsub_target = try(v.pubsub_target, null) != null ? {
        topic_name = v.pubsub_target.topic_name
        data       = try(v.pubsub_target.data, null) != null ? base64encode(v.pubsub_target.data) : null
        attributes = try(v.pubsub_target.attributes, {})
      } : null
    }
  }

  # ----------------------------------------------------------------------------
  # 6. Optional Legacy Serverless VPC Access Connectors
  # ----------------------------------------------------------------------------
  raw_vpc_connectors = try(local.cfg.serverless_vpc_connectors, {})

  serverless_vpc_connectors = {
    for k, v in local.raw_vpc_connectors : try(v.name, tostring(k)) => {
      name          = try(v.name, tostring(k))
      project_id    = try(v.project_id, local.default_project_id)
      region        = try(v.region, local.default_region)
      network       = try(v.network, local.default_network)
      ip_cidr_range = try(v.ip_cidr_range, null)
      subnet_name   = try(v.subnet_name, null)
      machine_type  = try(v.machine_type, "e2-micro")
      min_instances = tonumber(try(v.min_instances, 2))
      max_instances = tonumber(try(v.max_instances, 3))
    }
  }
}
