# ==============================================================================
# Outputs: GCP Dashboards & Uptime Infrastructure Module
# ==============================================================================

output "uptime_checks" {
  description = "Map of created synthetic uptime checks."
  value = {
    for k, v in google_monitoring_uptime_check_config.uptime_checks : k => {
      id              = v.id
      uptime_check_id = v.uptime_check_id
      name            = v.name
      display_name    = v.display_name
      period          = v.period
      timeout         = v.timeout
      regions         = v.selected_regions
    }
  }
}

output "uptime_failure_alert_policies" {
  description = "Map of automated uptime outage alert policies."
  value = {
    for k, v in google_monitoring_alert_policy.uptime_failure_alerts : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
      enabled      = v.enabled
    }
  }
}

output "ssl_expiry_alert_policies" {
  description = "Map of automated SSL/TLS certificate expiry alert policies."
  value = {
    for k, v in google_monitoring_alert_policy.ssl_expiry_alerts : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
      enabled      = v.enabled
    }
  }
}

output "dashboards" {
  description = "Map of created pre-packaged and custom Cloud Monitoring dashboards."
  value = merge(
    length(google_monitoring_dashboard.secops_dashboard) > 0 ? {
      "secops_dashboard" = {
        id = google_monitoring_dashboard.secops_dashboard[0].id
      }
    } : {},
    length(google_monitoring_dashboard.serverless_dashboard) > 0 ? {
      "serverless_dashboard" = {
        id = google_monitoring_dashboard.serverless_dashboard[0].id
      }
    } : {},
    length(google_monitoring_dashboard.network_dashboard) > 0 ? {
      "network_dashboard" = {
        id = google_monitoring_dashboard.network_dashboard[0].id
      }
    } : {},
    {
      for k, v in google_monitoring_dashboard.custom_dashboards : k => {
        id = v.id
      }
    }
  )
}

output "dashboards_uptime_summary" {
  description = "Summary metrics of uptime checks and dashboards provisioned."
  value = {
    uptime_checks_count         = length(google_monitoring_uptime_check_config.uptime_checks)
    uptime_failure_alerts_count = length(google_monitoring_alert_policy.uptime_failure_alerts)
    ssl_expiry_alerts_count     = length(google_monitoring_alert_policy.ssl_expiry_alerts)
    dashboards_count = (
      length(google_monitoring_dashboard.secops_dashboard) +
      length(google_monitoring_dashboard.serverless_dashboard) +
      length(google_monitoring_dashboard.network_dashboard) +
      length(google_monitoring_dashboard.custom_dashboards)
    )
  }
}
