# ==============================================================================
# Outputs: Audit & Compliance Setup Example
# ==============================================================================

output "audit_services" {
  description = "Enabled Data Access Audit Logging services."
  value       = module.audit_compliance.audit_services
}

output "storage_buckets" {
  description = "Created compliance Cloud Storage buckets."
  value       = module.audit_compliance.storage_buckets
}

output "bigquery_datasets" {
  description = "Created audit analytics BigQuery datasets."
  value       = module.audit_compliance.bigquery_datasets
}

output "pubsub_topics" {
  description = "Created SIEM streaming Pub/Sub topics."
  value       = module.audit_compliance.pubsub_topics
}

output "sinks" {
  description = "Centralized Cloud Logging sinks."
  value       = module.audit_compliance.sinks
}

output "sink_writer_identities" {
  description = "Writer identities for IAM binding verification."
  value       = module.audit_compliance.sink_writer_identities
}

output "security_metrics" {
  description = "Created CIS Benchmark and custom security metrics."
  value       = module.audit_compliance.security_metrics
}

output "summary" {
  description = "Resource deployment summary."
  value       = module.audit_compliance.summary
}
