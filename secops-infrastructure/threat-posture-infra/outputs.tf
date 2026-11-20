# ==============================================================================
# Outputs: Threat Posture Infrastructure (SCC & Cloud Asset Inventory)
# ==============================================================================

output "scc_notification_configs" {
  description = "Map of created Security Command Center v2 notification configs."
  value = {
    for k, n in google_scc_v2_project_notification_config.notifications : k => {
      id           = n.id
      config_id    = n.config_id
      pubsub_topic = n.pubsub_topic
    }
  }
}

output "scc_bigquery_exports" {
  description = "Map of created Security Command Center v2 BigQuery continuous finding exports."
  value = {
    for k, exp in google_scc_v2_project_scc_big_query_export.exports : k => {
      id                  = exp.id
      big_query_export_id = exp.big_query_export_id
      dataset             = exp.dataset
    }
  }
}

output "cloud_asset_feeds" {
  description = "Map of provisioned Cloud Asset Inventory real-time change feeds."
  value = {
    for k, f in google_cloud_asset_project_feed.feeds : k => {
      id           = f.id
      feed_id      = f.feed_id
      content_type = f.content_type
      asset_types  = f.asset_types
    }
  }
}

output "pubsub_topics" {
  description = "Map of created Pub/Sub topics across SCC and Cloud Asset feeds."
  value = {
    scc_topics   = { for k, t in google_pubsub_topic.scc_topics : k => t.id }
    asset_topics = { for k, t in google_pubsub_topic.asset_topics : k => t.id }
  }
}

output "summary" {
  description = "Summary metrics of provisioned threat posture resources."
  value = {
    scc_notifications_count = length(google_scc_v2_project_notification_config.notifications)
    scc_exports_count       = length(google_scc_v2_project_scc_big_query_export.exports)
    asset_feeds_count       = length(google_cloud_asset_project_feed.feeds)
    total_topics_count      = length(google_pubsub_topic.scc_topics) + length(google_pubsub_topic.asset_topics)
  }
}
