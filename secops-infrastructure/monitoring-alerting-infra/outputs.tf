# ==============================================================================
# Outputs: GCP Monitoring & Alerting Infrastructure Module
# ==============================================================================

output "scoping_project" {
  description = "The centralized Cloud Monitoring scoping project ID."
  value       = local.scoping_project
}

output "monitored_projects" {
  description = "Map of monitored projects linked into the central scoping project."
  value = {
    for k, v in google_monitoring_monitored_project.monitored_projects : k => {
      id              = v.id
      scoping_project = v.metrics_scope
      monitored_name  = v.name
    }
  }
}

output "notification_channels" {
  description = "Map of created Cloud Monitoring notification channels with their resolved IDs."
  value = {
    for k, v in google_monitoring_notification_channel.channels : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
      type         = v.type
      enabled      = v.enabled
    }
  }
}

output "cis_alert_policies" {
  description = "Map of created CIS GCP Benchmark v3 security alert policies."
  value = {
    for k, v in google_monitoring_alert_policy.cis_alerts : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
      enabled      = v.enabled
    }
  }
}

output "custom_alert_policies" {
  description = "Map of created custom operational and metric threshold alert policies."
  value = {
    for k, v in google_monitoring_alert_policy.custom_alerts : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
      enabled      = v.enabled
    }
  }
}

output "monitoring_summary" {
  description = "Summary count of monitoring resources provisioned."
  value = {
    scoping_project             = local.scoping_project
    monitored_projects_count    = length(google_monitoring_monitored_project.monitored_projects)
    notification_channels_count = length(google_monitoring_notification_channel.channels)
    cis_alert_policies_count    = length(google_monitoring_alert_policy.cis_alerts)
    custom_alert_policies_count = length(google_monitoring_alert_policy.custom_alerts)
  }
}
