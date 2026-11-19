# ==============================================================================
# 4. Automated Log Sink Writer IAM Delegation
# ==============================================================================
# Automatically binds appropriate destination write permissions to the unique
# writer identity generated for each Cloud Logging Sink:
# - Cloud Storage: roles/storage.objectCreator
# - BigQuery:      roles/bigquery.dataEditor
# - Pub/Sub:       roles/pubsub.publisher
# ==============================================================================

locals {
  # Aggregate all created sink writer identities across scopes
  sink_writer_identities = merge(
    { for k, s in google_logging_project_sink.project_sinks : k => s.writer_identity },
    { for k, s in google_logging_folder_sink.folder_sinks : k => s.writer_identity },
    { for k, s in google_logging_organization_sink.org_sinks : k => s.writer_identity }
  )

  # Cloud Storage Sinks requiring roles/storage.objectCreator
  storage_sink_iam = {
    for k, s in local.sinks : k => {
      sink_name       = s.name
      bucket          = s.dest_target
      writer_identity = try(local.sink_writer_identities[k], null)
    }
    if s.dest_type == "storage" && s.dest_target != null && s.auto_grant_iam
  }

  # BigQuery Sinks requiring roles/bigquery.dataEditor
  bigquery_sink_iam = {
    for k, s in local.sinks : k => {
      sink_name       = s.name
      project_id      = startswith(s.resolved_destination, "bigquery.googleapis.com/projects/") ? split("/", s.resolved_destination)[2] : try(s.target_id, local.default_project_id)
      dataset_id      = s.dest_target
      writer_identity = try(local.sink_writer_identities[k], null)
    }
    if s.dest_type == "bigquery" && s.dest_target != null && s.auto_grant_iam
  }

  # Pub/Sub Sinks requiring roles/pubsub.publisher
  pubsub_sink_iam = {
    for k, s in local.sinks : k => {
      sink_name       = s.name
      project_id      = startswith(s.resolved_destination, "pubsub.googleapis.com/projects/") ? split("/", s.resolved_destination)[2] : try(s.target_id, local.default_project_id)
      topic           = s.dest_target
      writer_identity = try(local.sink_writer_identities[k], null)
    }
    if s.dest_type == "pubsub" && s.dest_target != null && s.auto_grant_iam
  }
}

# ------------------------------------------------------------------------------
# Storage Writer IAM Delegation
# ------------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "sink_storage_writer" {
  for_each = local.storage_sink_iam

  bucket = each.value.bucket
  role   = "roles/storage.objectCreator"
  member = each.value.writer_identity

  depends_on = [
    google_storage_bucket.audit_buckets,
    google_logging_project_sink.project_sinks,
    google_logging_folder_sink.folder_sinks,
    google_logging_organization_sink.org_sinks
  ]
}

# ------------------------------------------------------------------------------
# BigQuery Writer IAM Delegation
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset_iam_member" "sink_bigquery_writer" {
  for_each = local.bigquery_sink_iam

  dataset_id = each.value.dataset_id
  project    = each.value.project_id
  role       = "roles/bigquery.dataEditor"
  member     = each.value.writer_identity

  depends_on = [
    google_bigquery_dataset.audit_datasets,
    google_logging_project_sink.project_sinks,
    google_logging_folder_sink.folder_sinks,
    google_logging_organization_sink.org_sinks
  ]
}

# ------------------------------------------------------------------------------
# Pub/Sub Writer IAM Delegation
# ------------------------------------------------------------------------------
resource "google_pubsub_topic_iam_member" "sink_pubsub_writer" {
  for_each = local.pubsub_sink_iam

  topic   = each.value.topic
  project = each.value.project_id
  role    = "roles/pubsub.publisher"
  member  = each.value.writer_identity

  depends_on = [
    google_pubsub_topic.audit_topics,
    google_logging_project_sink.project_sinks,
    google_logging_folder_sink.folder_sinks,
    google_logging_organization_sink.org_sinks
  ]
}
