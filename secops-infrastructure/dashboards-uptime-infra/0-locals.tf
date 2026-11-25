# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses YAML configuration and flattens synthetic uptime check configurations,
# SSL/TLS expiration alert policies, uptime failure alert policies, and
# operational Cloud Monitoring dashboards for Terraform 'for_each' iteration.
# ==============================================================================

locals {
  # ----------------------------------------------------------------------------
  # Raw Configuration Input (File Path or Raw Content)
  # ----------------------------------------------------------------------------
  raw_config = yamldecode(
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? file(var.config_file_path) : "{}"
    )
  )

  # Top-level global defaults
  default_project_id = try(local.raw_config.project_id, null)
  common_labels      = try(local.raw_config.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Synthetic Uptime Checks
  # ----------------------------------------------------------------------------
  raw_uptime_checks = try(local.raw_config.uptime_checks, [])

  uptime_checks = {
    for u in local.raw_uptime_checks : u.name => {
      name             = u.name
      project_id       = try(u.project_id, local.default_project_id)
      display_name     = try(u.display_name, u.name)
      host             = u.host
      protocol         = upper(try(u.protocol, "HTTPS"))
      path             = try(u.path, "/")
      port             = try(u.port, upper(try(u.protocol, "HTTPS")) == "HTTPS" ? 443 : 80)
      timeout          = try(u.timeout, "10s")
      period           = try(u.period, "60s")
      selected_regions = try(u.selected_regions, ["USA", "EUROPE", "ASIA_PACIFIC"])
      validate_ssl     = try(u.validate_ssl, true)
      headers          = try(u.headers, {})
      body             = try(u.body, null)
      request_method   = upper(try(u.request_method, "GET"))
      content_type     = try(u.content_type, null)
      checker_type     = try(u.checker_type, "STATIC_IP_CHECKERS")

      # Alerting toggles & thresholds
      alert_on_failure      = try(u.alert_on_failure, true)
      alert_on_ssl_expiry   = try(u.alert_on_ssl_expiry, upper(try(u.protocol, "HTTPS")) == "HTTPS")
      ssl_expiry_days       = try(u.ssl_expiry_days, 30)
      notification_channels = try(u.notification_channels, [])

      # Content matchers
      content_matchers = [
        for cm in try(u.content_matchers, []) : {
          content = cm.content
          matcher = try(cm.matcher, "CONTAINS_STRING")
        }
      ]

      # Accepted HTTP Status Codes (e.g. 200, 204)
      status_classes = try(u.status_classes, ["STATUS_CLASS_2XX"])
    }
  }

  # ----------------------------------------------------------------------------
  # 2. Automated Uptime Failure Alert Policies
  # ----------------------------------------------------------------------------
  uptime_failure_alerts = {
    for k, v in local.uptime_checks : k => {
      name                  = "${k}-uptime-failure"
      project_id            = v.project_id
      uptime_check_name     = k
      display_name          = "[Uptime Alert] Service Outage Detected: ${v.display_name}"
      notification_channels = v.notification_channels
      doc_summary           = "Synthetic probe failed to reach host '${v.host}${v.path}' across probed regions (${join(", ", v.selected_regions)})."
    }
    if v.alert_on_failure
  }

  # ----------------------------------------------------------------------------
  # 3. Automated SSL/TLS Certificate Expiry Alert Policies
  # ----------------------------------------------------------------------------
  ssl_cert_alerts = {
    for k, v in local.uptime_checks : k => {
      name                  = "${k}-ssl-expiry"
      project_id            = v.project_id
      uptime_check_name     = k
      display_name          = "[Security Alert] SSL/TLS Certificate Expiring: ${v.display_name}"
      notification_channels = v.notification_channels
      ssl_expiry_days       = v.ssl_expiry_days
      # Convert days to seconds for Cloud Monitoring threshold
      threshold_seconds     = v.ssl_expiry_days * 86400
      doc_summary           = "The TLS/SSL certificate for host '${v.host}' expires in less than ${v.ssl_expiry_days} days. Renew certificate immediately to avoid production service interruption."
    }
    if v.alert_on_ssl_expiry && v.protocol == "HTTPS"
  }

  # ----------------------------------------------------------------------------
  # 4. Cloud Monitoring Dashboards
  # ----------------------------------------------------------------------------
  raw_dashboards = try(local.raw_config.dashboards, {})

  enable_secops_dashboard     = try(local.raw_dashboards.enable_secops_dashboard, true)
  enable_serverless_dashboard = try(local.raw_dashboards.enable_serverless_dashboard, true)
  enable_network_dashboard    = try(local.raw_dashboards.enable_network_dashboard, true)

  # Custom dashboards declared via YAML
  custom_dashboards = {
    for d in try(local.raw_dashboards.custom_dashboards, []) : d.name => {
      name         = d.name
      project_id   = try(d.project_id, local.default_project_id)
      display_name = try(d.display_name, d.name)
      dashboard_json = try(d.dashboard_json, null) != null ? d.dashboard_json : (
        try(d.json_file_path, null) != null ? file(d.json_file_path) : "{}"
      )
    }
  }
}
