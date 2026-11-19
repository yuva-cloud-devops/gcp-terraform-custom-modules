# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the YAML configuration and flattens Data Access audit log configs,
# managed destinations, centralized log sinks, writer IAM delegations, and
# CIS GCP Benchmark security metrics for Terraform 'for_each' iteration.
# ==============================================================================

locals {
  # ----------------------------------------------------------------------------
  # Raw Configuration Input (File Path or Raw Content)
  # ----------------------------------------------------------------------------
  raw_config = yamldecode(
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? file(var.config_file_path) : "{}"
    )
  )

  # Top-level global defaults
  default_project_id = try(local.raw_config.project_id, null)
  default_location   = try(local.raw_config.default_location, local.raw_config.location, "asia-south1")
  common_labels      = try(local.raw_config.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Data Access Audit Logs Configuration
  # ----------------------------------------------------------------------------
  raw_audit = try(local.raw_config.audit_logs, {})

  audit_scope     = lower(try(local.raw_audit.scope, "project"))
  audit_target_id = try(local.raw_audit.target_id, local.raw_audit.id, local.default_project_id)

  raw_audit_services = try(local.raw_audit.services, [])

  audit_services_map = {
    for s in local.raw_audit_services : s.service => {
      service          = s.service
      log_types        = try(s.log_types, ["ADMIN_READ", "DATA_READ", "DATA_WRITE"])
      exempted_members = try(s.exempted_members, [])
    }
  }

  # ----------------------------------------------------------------------------
  # 2. Managed Audit Destinations (Optional Managed Storage)
  # ----------------------------------------------------------------------------
  raw_destinations = try(local.raw_config.destinations, {})

  # Cloud Storage Buckets (Compliance cold storage / WORM retention)
  storage_buckets = {
    for b in try(local.raw_destinations.storage_buckets, []) : b.name => {
      name          = b.name
      project_id    = try(b.project_id, local.default_project_id)
      location      = try(b.location, local.default_location)
      storage_class = try(b.storage_class, "STANDARD")
      versioning    = try(b.versioning, true)
      labels        = merge(local.common_labels, try(b.labels, {}))
      kms_key_name  = try(b.kms_key_name, null)
      retention_policy = try(b.retention_policy, null) != null ? {
        retention_period = try(b.retention_policy.retention_period_days, 365) * 86400
        is_locked        = try(b.retention_policy.is_locked, false)
      } : null
      lifecycle_rules = try(b.lifecycle_rules, [])
    }
  }

  # BigQuery Datasets (Audit analytics & threat hunting)
  bigquery_datasets = {
    for d in try(local.raw_destinations.bigquery_datasets, []) : d.dataset_id => {
      dataset_id                  = d.dataset_id
      project_id                  = try(d.project_id, local.default_project_id)
      location                    = try(d.location, local.default_location)
      description                 = try(d.description, "Centralized Security Audit Analytics Dataset")
      default_table_expiration_ms = try(d.default_table_expiration_ms, null)
      labels                      = merge(local.common_labels, try(d.labels, {}))
      kms_key_name                = try(d.kms_key_name, null)
    }
  }

  # Cloud Pub/Sub Topics (SIEM streaming to Splunk, Chronicle, Datadog)
  pubsub_topics = {
    for t in try(local.raw_destinations.pubsub_topics, []) : t.name => {
      name         = t.name
      project_id   = try(t.project_id, local.default_project_id)
      labels       = merge(local.common_labels, try(t.labels, {}))
      kms_key_name = try(t.kms_key_name, null)
    }
  }

  # ----------------------------------------------------------------------------
  # 3. Centralized Log Sinks
  # ----------------------------------------------------------------------------
  raw_sinks = try(local.raw_config.log_sinks, local.raw_config.sinks, [])

  sinks = {
    for s in local.raw_sinks : s.name => {
      name                   = s.name
      scope                  = lower(try(s.scope, "project"))
      target_id              = try(s.target_id, local.default_project_id)
      filter                 = try(s.filter, "protoPayload.@type=\"type.googleapis.com/google.cloud.audit.AuditLog\"")
      include_children       = try(s.include_children, false)
      unique_writer_identity = try(s.unique_writer_identity, true)
      auto_grant_iam         = try(s.auto_grant_iam, try(s.grant_writer_permission, true))
      raw_destination        = s.destination

      # Resolved Destination URI:
      # Converts shorthand 'bucket:name', 'bigquery:dataset_id', 'pubsub:topic_name'
      # or accepts direct GCP destination URIs: 'storage.googleapis.com/...', etc.
      resolved_destination = (
        startswith(s.destination, "bucket:") ?
        "storage.googleapis.com/${split(":", s.destination)[1]}" : (
          startswith(s.destination, "bigquery:") ?
          "bigquery.googleapis.com/projects/${try(s.target_id, local.default_project_id)}/datasets/${split(":", s.destination)[1]}" : (
            startswith(s.destination, "pubsub:") ?
            "pubsub.googleapis.com/projects/${try(s.target_id, local.default_project_id)}/topics/${split(":", s.destination)[1]}" :
            s.destination
          )
        )
      )

      destination = (
        startswith(s.destination, "bucket:") ?
        "storage.googleapis.com/${split(":", s.destination)[1]}" : (
          startswith(s.destination, "bigquery:") ?
          "bigquery.googleapis.com/projects/${try(s.target_id, local.default_project_id)}/datasets/${split(":", s.destination)[1]}" : (
            startswith(s.destination, "pubsub:") ?
            "pubsub.googleapis.com/projects/${try(s.target_id, local.default_project_id)}/topics/${split(":", s.destination)[1]}" :
            s.destination
          )
        )
      )

      # Destination type tag (storage, bigquery, pubsub, or external)
      dest_type = (
        startswith(s.destination, "bucket:") || startswith(s.destination, "storage.googleapis.com/") ? "storage" : (
          startswith(s.destination, "bigquery:") || startswith(s.destination, "bigquery.googleapis.com/") ? "bigquery" : (
            startswith(s.destination, "pubsub:") || startswith(s.destination, "pubsub.googleapis.com/") ? "pubsub" : "other"
          )
        )
      )

      # Target Resource Name for IAM Binding
      dest_target = (
        startswith(s.destination, "bucket:") ? split(":", s.destination)[1] : (
          startswith(s.destination, "storage.googleapis.com/") ? split("/", s.destination)[1] : (
            startswith(s.destination, "bigquery:") ? split(":", s.destination)[1] : (
              startswith(s.destination, "bigquery.googleapis.com/") ? split("/", s.destination)[length(split("/", s.destination)) - 1] : (
                startswith(s.destination, "pubsub:") ? split(":", s.destination)[1] : (
                  startswith(s.destination, "pubsub.googleapis.com/") ? split("/", s.destination)[length(split("/", s.destination)) - 1] : null
                )
              )
            )
          )
        )
      )

      exclusions = [
        for e in try(s.exclusions, []) : {
          name        = e.name
          description = try(e.description, null)
          filter      = e.filter
          disabled    = try(e.disabled, false)
        }
      ]
    }
  }

  # Partition sinks by scope for dedicated resource blocks
  project_sinks = { for k, v in local.sinks : k => v if v.scope == "project" }
  folder_sinks  = { for k, v in local.sinks : k => v if v.scope == "folder" }
  org_sinks     = { for k, v in local.sinks : k => v if v.scope == "organization" || v.scope == "org" }

  # ----------------------------------------------------------------------------
  # 4. CIS GCP Benchmark Log-Based Security Metrics
  # ----------------------------------------------------------------------------
  raw_security_metrics  = try(local.raw_config.security_metrics, {})
  enable_cis_benchmarks = try(local.raw_security_metrics.enable_cis_benchmarks, true)

  # Official CIS Google Cloud Platform Foundations Benchmark Security Filters
  cis_benchmark_filters = {
    "cis_iam_policy_changes" = {
      description = "CIS 2.4: Alerts on IAM role and policy assignment changes"
      filter      = "(protoPayload.serviceName=\"iam.googleapis.com\" OR protoPayload.serviceName=\"resourcemanager.googleapis.com\") AND (protoPayload.methodName:\"SetIamPolicy\" OR protoPayload.methodName:\"SetOrgPolicy\")"
    }
    "cis_audit_config_changes" = {
      description = "CIS 2.5: Alerts on Data Access audit logging configuration changes"
      filter      = "protoPayload.methodName=\"SetIamPolicy\" AND protoPayload.serviceData.policyDelta.auditConfigDeltas:*"
    }
    "cis_custom_role_changes" = {
      description = "CIS 2.6: Alerts on Custom IAM Role creation, deletion, or modifications"
      filter      = "resource.type=\"iam_role\" AND (protoPayload.methodName:\"CreateRole\" OR protoPayload.methodName:\"DeleteRole\" OR protoPayload.methodName:\"UpdateRole\")"
    }
    "cis_firewall_rule_changes" = {
      description = "CIS 2.7: Alerts on VPC firewall rule creation, deletion, or modification"
      filter      = "resource.type=\"gce_firewall_rule\" AND (protoPayload.methodName:\"insert\" OR protoPayload.methodName:\"delete\" OR protoPayload.methodName:\"patch\")"
    }
    "cis_network_route_changes" = {
      description = "CIS 2.8: Alerts on VPC network route creation, deletion, or modification"
      filter      = "resource.type=\"gce_route\" AND (protoPayload.methodName:\"insert\" OR protoPayload.methodName:\"delete\")"
    }
    "cis_vpc_network_changes" = {
      description = "CIS 2.9: Alerts on VPC network creation, deletion, or subnet modification"
      filter      = "resource.type=\"gce_network\" AND (protoPayload.methodName:\"insert\" OR protoPayload.methodName:\"delete\" OR protoPayload.methodName:\"patch\")"
    }
    "cis_storage_iam_changes" = {
      description = "CIS 2.10: Alerts on Cloud Storage bucket IAM permission changes"
      filter      = "protoPayload.serviceName=\"storage.googleapis.com\" AND protoPayload.methodName=\"storage.setIamPermissions\""
    }
    "cis_cloud_sql_changes" = {
      description = "CIS 2.11: Alerts on Cloud SQL database instance configuration updates"
      filter      = "protoPayload.serviceName=\"cloudsql.googleapis.com\" AND (protoPayload.methodName:\"update\" OR protoPayload.methodName:\"delete\")"
    }
    "cis_kms_key_destruction" = {
      description = "CIS 2.12: Alerts on Cloud KMS cryptographic key scheduled destruction"
      filter      = "protoPayload.serviceName=\"cloudkms.googleapis.com\" AND protoPayload.methodName=\"google.crypto.kms.v1.KeyManagementService.DestroyCryptoKeyVersion\""
    }
  }

  # Combined metrics: CIS Benchmark filters + user-defined custom metrics
  all_metrics = merge(
    local.enable_cis_benchmarks ? {
      for k, v in local.cis_benchmark_filters : k => {
        name        = k
        project_id  = local.default_project_id
        description = v.description
        filter      = v.filter
      }
    } : {},
    {
      for m in try(local.raw_security_metrics.custom_metrics, []) : m.name => {
        name        = m.name
        project_id  = try(m.project_id, local.default_project_id)
        description = try(m.description, "Custom security log-based metric")
        filter      = m.filter
      }
    }
  )
}
