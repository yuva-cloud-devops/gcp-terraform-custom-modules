# ==============================================================================
# Outputs: Threat Posture Infrastructure (SCC & Cloud Asset Inventory)
# ==============================================================================


output "scc_notifications" {
  description = "Security Command Center v2 notification configs."
  value       = module.threat_posture.scc_notification_configs
}

output "cloud_asset_feeds" {
  description = "Cloud Asset Inventory real-time drift feeds."
  value       = module.threat_posture.cloud_asset_feeds
}

output "pubsub_topics" {
  description = "Provisioned Pub/Sub topics."
  value       = module.threat_posture.pubsub_topics
}

output "summary" {
  description = "Summary metrics of threat posture resources."
  value       = module.threat_posture.summary
}
