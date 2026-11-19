# ==============================================================================
# Outputs: GCP Audit & Compliance Infrastructure Module
# ==============================================================================

output "audit_scope" {
  description = "The target hierarchy scope configured for Data Access Audit Logs."
  value       = local.audit_scope
}

output "audit_target_id" {
  description = "The target resource ID (project ID, folder ID, or org ID) for Data Access Audit Logs."
  value       = local.audit_target_id
}

output "audit_services" {
  description = "Map of services configured with Data Access Audit Logging."
  value       = local.audit_services_map
}

output "storage_buckets" {
  description = "Map of created compliance Cloud Storage buckets."
  value = {
    for k, b in google_storage_bucket.audit_buckets : k => {
      name     = b.name
      id       = b.id
      url      = b.url
      location = b.location
    }
  }
}

output "bigquery_datasets" {
  description = "Map of created audit analytics BigQuery datasets."
  value = {
    for k, d in google_bigquery_dataset.audit_datasets : k => {
      dataset_id = d.dataset_id
      id         = d.id
      project    = d.project
      location   = d.location
    }
  }
}

output "pubsub_topics" {
  description = "Map of created SIEM streaming Pub/Sub topics."
  value = {
    for k, t in google_pubsub_topic.audit_topics : k => {
      name    = t.name
      id      = t.id
      project = t.project
    }
  }
}

output "sinks" {
  description = "Map of created Cloud Logging sinks across all scopes."
  value = merge(
    {
      for k, s in google_logging_project_sink.project_sinks : k => {
        name            = s.name
        scope           = "project"
        target_id       = s.project
        destination     = s.destination
        filter          = s.filter
        writer_identity = s.writer_identity
      }
    },
    {
      for k, s in google_logging_folder_sink.folder_sinks : k => {
        name            = s.name
        scope           = "folder"
        target_id       = s.folder
        destination     = s.destination
        filter          = s.filter
        writer_identity = s.writer_identity
      }
    },
    {
      for k, s in google_logging_organization_sink.org_sinks : k => {
        name            = s.name
        scope           = "organization"
        target_id       = s.org_id
        destination     = s.destination
        filter          = s.filter
        writer_identity = s.writer_identity
      }
    }
  )
}

output "sink_writer_identities" {
  description = "Map of sink name to writer identity service account for IAM delegation."
  value       = local.sink_writer_identities
}

output "security_metrics" {
  description = "Map of created CIS Benchmark and custom security log-based metrics."
  value = {
    for k, m in google_logging_metric.security_metrics : k => {
      name        = m.name
      id          = m.id
      project     = m.project
      description = m.description
      filter      = m.filter
    }
  }
}

output "summary" {
  description = "High-level summary count of all configured audit and compliance resources."
  value = {
    audit_services_count   = length(local.audit_services_map)
    storage_buckets_count  = length(google_storage_bucket.audit_buckets)
    bigquery_dataset_count = length(google_bigquery_dataset.audit_datasets)
    pubsub_topics_count    = length(google_pubsub_topic.audit_topics)
    total_sinks_count      = length(local.sinks)
    project_sinks_count    = length(google_logging_project_sink.project_sinks)
    folder_sinks_count     = length(google_logging_folder_sink.folder_sinks)
    org_sinks_count        = length(google_logging_organization_sink.org_sinks)
    security_metrics_count = length(google_logging_metric.security_metrics)
  }
}
