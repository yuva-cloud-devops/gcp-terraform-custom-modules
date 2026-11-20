# ==============================================================================
# 1. Security Command Center (SCC) Finding Notifications & Alert Streaming
# ==============================================================================
# Provisions real-time streaming notifications for active security vulnerabilities,
# compliance violations, and anomalous threat detections to Cloud Pub/Sub topics.
# Automatically grants the SCC Google-managed service account publishing rights.
# ==============================================================================

# ------------------------------------------------------------------------------
# Managed Pub/Sub Topics for SCC Notifications
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "scc_topics" {
  for_each = {
    for k, v in local.managed_topics_map : k => v
    if v.purpose == "scc"
  }

  name    = each.value.name
  project = each.value.project_id
  labels  = local.common_labels
}

# ------------------------------------------------------------------------------
# SCC v2 Project Notification Configurations (Real-Time Finding Streaming)
# ------------------------------------------------------------------------------
resource "google_scc_v2_project_notification_config" "notifications" {
  for_each = local.scc_notifications_map

  config_id   = each.value.config_id
  project     = each.value.project_id
  location    = each.value.location
  description = each.value.description

  pubsub_topic = (
    startswith(each.value.topic_name, "projects/") ?
    each.value.topic_name :
    google_pubsub_topic.scc_topics["scc-${each.key}"].id
  )

  streaming_config {
    filter = each.value.filter
  }

  depends_on = [
    google_pubsub_topic.scc_topics
  ]
}

# ------------------------------------------------------------------------------
# IAM Delegation: Allow SCC Notification Service Account to Publish to Topic
# ------------------------------------------------------------------------------
resource "google_pubsub_topic_iam_member" "scc_publisher" {
  for_each = {
    for k, v in local.scc_notifications_map : k => v
    if v.create_topic && !startswith(v.topic_name, "projects/")
  }

  project = each.value.project_id
  topic   = google_pubsub_topic.scc_topics["scc-${each.key}"].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_scc_v2_project_notification_config.notifications[each.key].service_account}"

  depends_on = [
    google_scc_v2_project_notification_config.notifications
  ]
}
