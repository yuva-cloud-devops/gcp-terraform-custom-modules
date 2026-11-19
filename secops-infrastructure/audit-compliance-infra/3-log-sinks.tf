# ==============================================================================
# 3. Centralized Cloud Logging Sinks
# ==============================================================================
# Declares Cloud Logging Sinks across Project, Folder, or Organization hierarchy.
# Routes security, audit, and compliance logs to dedicated destinations (Storage,
# BigQuery, Pub/Sub) with optional filtering and exclusion rules.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project-Level Log Sinks
# ------------------------------------------------------------------------------
resource "google_logging_project_sink" "project_sinks" {
  for_each = local.project_sinks

  name                   = each.value.name
  project                = each.value.target_id
  destination            = each.value.resolved_destination
  filter                 = each.value.filter
  unique_writer_identity = each.value.unique_writer_identity

  dynamic "exclusions" {
    for_each = each.value.exclusions
    content {
      name        = exclusions.value.name
      description = exclusions.value.description
      filter      = exclusions.value.filter
      disabled    = exclusions.value.disabled
    }
  }

  depends_on = [
    google_storage_bucket.audit_buckets,
    google_bigquery_dataset.audit_datasets,
    google_pubsub_topic.audit_topics
  ]
}

# ------------------------------------------------------------------------------
# Folder-Level Log Sinks (Aggregated / Inherited)
# ------------------------------------------------------------------------------
resource "google_logging_folder_sink" "folder_sinks" {
  for_each = local.folder_sinks

  name             = each.value.name
  folder           = each.value.target_id
  destination      = each.value.resolved_destination
  filter           = each.value.filter
  include_children = each.value.include_children

  dynamic "exclusions" {
    for_each = each.value.exclusions
    content {
      name        = exclusions.value.name
      description = exclusions.value.description
      filter      = exclusions.value.filter
      disabled    = exclusions.value.disabled
    }
  }

  depends_on = [
    google_storage_bucket.audit_buckets,
    google_bigquery_dataset.audit_datasets,
    google_pubsub_topic.audit_topics
  ]
}

# ------------------------------------------------------------------------------
# Organization-Level Log Sinks (Enterprise-Wide Aggregated)
# ------------------------------------------------------------------------------
resource "google_logging_organization_sink" "org_sinks" {
  for_each = local.org_sinks

  name             = each.value.name
  org_id           = each.value.target_id
  destination      = each.value.resolved_destination
  filter           = each.value.filter
  include_children = each.value.include_children

  dynamic "exclusions" {
    for_each = each.value.exclusions
    content {
      name        = exclusions.value.name
      description = exclusions.value.description
      filter      = exclusions.value.filter
      disabled    = exclusions.value.disabled
    }
  }

  depends_on = [
    google_storage_bucket.audit_buckets,
    google_bigquery_dataset.audit_datasets,
    google_pubsub_topic.audit_topics
  ]
}
