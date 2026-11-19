# ==============================================================================
# 2. Managed Audit Log Destinations
# ==============================================================================
# Provisions optional dedicated compliance storage destinations:
# 1. Cloud Storage Buckets (Compliance WORM retention, versioning, cold storage)
# 2. BigQuery Datasets (Security analytics, threat hunting, SQL auditing)
# 3. Cloud Pub/Sub Topics (Streaming audit logs to SIEM: Splunk, Chronicle, Datadog)
# ==============================================================================

# ------------------------------------------------------------------------------
# Compliance Cloud Storage Buckets
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "audit_buckets" {
  for_each = local.storage_buckets

  name                        = each.value.name
  project                     = each.value.project_id
  location                    = each.value.location
  storage_class               = each.value.storage_class
  uniform_bucket_level_access = true
  labels                      = each.value.labels

  versioning {
    enabled = each.value.versioning
  }

  dynamic "retention_policy" {
    for_each = each.value.retention_policy != null ? [each.value.retention_policy] : []
    content {
      retention_period = retention_policy.value.retention_period
      is_locked        = retention_policy.value.is_locked
    }
  }

  dynamic "encryption" {
    for_each = each.value.kms_key_name != null ? [each.value.kms_key_name] : []
    content {
      default_kms_key_name = encryption.value
    }
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }
      condition {
        age                        = try(lifecycle_rule.value.condition.age, null)
        created_before             = try(lifecycle_rule.value.condition.created_before, null)
        with_state                 = try(lifecycle_rule.value.condition.with_state, null)
        matches_storage_class      = try(lifecycle_rule.value.condition.matches_storage_class, null)
        num_newer_versions         = try(lifecycle_rule.value.condition.num_newer_versions, null)
        days_since_noncurrent_time = try(lifecycle_rule.value.condition.days_since_noncurrent_time, null)
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Audit Analytics BigQuery Datasets
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "audit_datasets" {
  for_each = local.bigquery_datasets

  dataset_id                  = each.value.dataset_id
  project                     = each.value.project_id
  location                    = each.value.location
  description                 = each.value.description
  default_table_expiration_ms = each.value.default_table_expiration_ms
  labels                      = each.value.labels

  dynamic "default_encryption_configuration" {
    for_each = each.value.kms_key_name != null ? [each.value.kms_key_name] : []
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }
}

# ------------------------------------------------------------------------------
# SIEM Streaming Pub/Sub Topics
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "audit_topics" {
  for_each = local.pubsub_topics

  name         = each.value.name
  project      = each.value.project_id
  labels       = each.value.labels
  kms_key_name = each.value.kms_key_name
}
