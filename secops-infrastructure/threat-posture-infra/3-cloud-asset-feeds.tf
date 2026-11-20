# ==============================================================================
# 3. Cloud Asset Inventory (CAI) Real-Time Drift & Change Feeds
# ==============================================================================
# Provisions real-time Cloud Asset Inventory project feeds that emit Pub/Sub
# notifications whenever critical cloud infrastructure resources (Firewalls,
# IAM Service Accounts, Storage Buckets, KMS Keys) are created, modified, or deleted.
# Automatically grants the Google-managed Cloud Asset service account publishing rights.
# ==============================================================================

# ------------------------------------------------------------------------------
# Managed Pub/Sub Topics for Cloud Asset Inventory Feeds
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "asset_topics" {
  for_each = {
    for k, v in local.managed_topics_map : k => v
    if v.purpose == "asset"
  }

  name    = each.value.name
  project = each.value.project_id
  labels  = local.common_labels
}

# ------------------------------------------------------------------------------
# IAM Delegation: Allow Cloud Asset Inventory Service Account to Publish to Topic
# ------------------------------------------------------------------------------
resource "google_pubsub_topic_iam_member" "asset_publisher" {
  for_each = {
    for k, v in local.asset_feeds_map : k => v
    if v.create_topic && !startswith(v.topic_name, "projects/")
  }

  project = each.value.project_id
  topic   = google_pubsub_topic.asset_topics["asset-${each.key}"].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudasset.iam.gserviceaccount.com"
}

# ------------------------------------------------------------------------------
# Cloud Asset Inventory Project Feeds (Real-Time Configuration Drift Monitoring)
# ------------------------------------------------------------------------------
resource "google_cloud_asset_project_feed" "feeds" {
  for_each = local.asset_feeds_map

  feed_id      = each.value.feed_id
  project      = each.value.project_id
  content_type = each.value.content_type
  asset_types  = each.value.asset_types

  feed_output_config {
    pubsub_destination {
      topic = (
        startswith(each.value.topic_name, "projects/") ?
        each.value.topic_name :
        google_pubsub_topic.asset_topics["asset-${each.key}"].id
      )
    }
  }

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      expression  = condition.value.expression
      title       = try(condition.value.title, "Asset change condition")
      description = try(condition.value.description, "Filtered asset event condition")
    }
  }

  depends_on = [
    google_pubsub_topic_iam_member.asset_publisher
  ]
}
