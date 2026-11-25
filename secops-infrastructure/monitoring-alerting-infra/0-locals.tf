# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the YAML configuration and flattens multi-project metric scopes,
# notification channels, CIS GCP Benchmark security alert policies, and
# operational metric threshold alerting rules for Terraform 'for_each' iteration.
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
  # 1. Multi-Project Metric Scopes
  # ----------------------------------------------------------------------------
  # Links remote monitored projects into the centralized scoping project.
  raw_metric_scopes = try(local.raw_config.metric_scopes, {})
  scoping_project   = try(local.raw_metric_scopes.scoping_project, local.default_project_id)
  
  monitored_projects = {
    for p in try(local.raw_metric_scopes.monitored_projects, []) : p => {
      scoping_project   = local.scoping_project
      monitored_project = p
    }
    if p != local.scoping_project
  }

  # ----------------------------------------------------------------------------
  # 2. Notification Channels
  # ----------------------------------------------------------------------------
  raw_channels = try(local.raw_config.notification_channels, [])

  notification_channels = {
    for c in local.raw_channels : c.name => {
      name             = c.name
      project_id       = try(c.project_id, local.default_project_id)
      display_name     = try(c.display_name, c.name)
      type             = lower(c.type)
      description      = try(c.description, "Managed notification channel for SecOps & infrastructure alerts")
      enabled          = try(c.enabled, true)
      labels           = try(c.labels, {})
      sensitive_labels = try(c.sensitive_labels, {})
      user_labels      = merge(local.common_labels, try(c.user_labels, {}))
    }
  }

  # Helper lookup to resolve channel names in alert policy configs
  channel_lookup = {
    for k, v in google_monitoring_notification_channel.channels : k => v.id
  }

  # ----------------------------------------------------------------------------
  # 3. CIS GCP Benchmark v3 Security Alerts (Section 2 Controls 2.4 - 2.12)
  # ----------------------------------------------------------------------------
  raw_cis_alerts     = try(local.raw_config.cis_security_alerts, {})
  enable_cis_alerts  = try(local.raw_cis_alerts.enable, true)
  cis_auto_close     = try(local.raw_cis_alerts.auto_close, "604800s") # 7 days
  cis_target_project = try(local.raw_cis_alerts.project_id, local.default_project_id)

  # Default notification channels for CIS alerts (resolved to channel names or raw IDs)
  cis_channel_names = try(local.raw_cis_alerts.notification_channels, [])
  cis_resolved_channels = [
    for ch in local.cis_channel_names :
    try(local.channel_lookup[ch], ch)
  ]

  # Built-in CIS Benchmark Alert Definitions (matching Domain 1 log metrics)
  default_cis_definitions = {
    "cis_iam_policy_changes" = {
      control     = "CIS 2.4"
      metric_name = "cis_iam_policy_changes"
      display_name = "[CIS 2.4] Security Alert: IAM Policy Changes Detected"
      doc_summary  = "An IAM policy modification occurred. Investigate immediately to verify authorization and prevent unauthorized privilege escalation."
      severity     = "CRITICAL"
    }
    "cis_audit_config_changes" = {
      control     = "CIS 2.5"
      metric_name = "cis_audit_config_changes"
      display_name = "[CIS 2.5] Security Alert: Audit Logging Configuration Modified"
      doc_summary  = "Data Access audit logging configuration was altered. Disabling audit logs can blind forensic threat detection."
      severity     = "CRITICAL"
    }
    "cis_custom_role_changes" = {
      control     = "CIS 2.6"
      metric_name = "cis_custom_role_changes"
      display_name = "[CIS 2.6] Security Alert: Custom IAM Role Created, Deleted or Updated"
      doc_summary  = "A custom IAM role was modified. Verify whether new permissions grant overly permissive or administrative access."
      severity     = "ERROR"
    }
    "cis_firewall_rule_changes" = {
      control     = "CIS 2.7"
      metric_name = "cis_firewall_rule_changes"
      display_name = "[CIS 2.7] Security Alert: VPC Firewall Rule Modified"
      doc_summary  = "A VPC firewall rule was inserted, deleted, or patched. Ensure zero open access to administrative ports (SSH 22, RDP 3389)."
      severity     = "ERROR"
    }
    "cis_network_route_changes" = {
      control     = "CIS 2.8"
      metric_name = "cis_network_route_changes"
      display_name = "[CIS 2.8] Security Alert: VPC Network Route Modified"
      doc_summary  = "A custom VPC network route was created or removed. Verify route targets to prevent unauthorized traffic redirection."
      severity     = "ERROR"
    }
    "cis_vpc_network_changes" = {
      control     = "CIS 2.9"
      metric_name = "cis_vpc_network_changes"
      display_name = "[CIS 2.9] Security Alert: VPC Network or Subnet Modified"
      doc_summary  = "VPC network topology or subnet configuration was updated. Review against zero-trust architectural blueprints."
      severity     = "WARNING"
    }
    "cis_storage_iam_changes" = {
      control     = "CIS 2.10"
      metric_name = "cis_storage_iam_changes"
      display_name = "[CIS 2.10] Security Alert: Cloud Storage IAM Permissions Modified"
      doc_summary  = "Bucket IAM permissions changed. Ensure allUsers/allAuthenticatedUsers are prohibited from accessing sensitive compliance data."
      severity     = "CRITICAL"
    }
    "cis_cloud_sql_changes" = {
      control     = "CIS 2.11"
      metric_name = "cis_cloud_sql_changes"
      display_name = "[CIS 2.11] Security Alert: Cloud SQL Database Configuration Updated"
      doc_summary  = "A managed database instance was modified or deleted. Confirm whether unauthorized public IPs or flags were applied."
      severity     = "ERROR"
    }
    "cis_kms_key_destruction" = {
      control     = "CIS 2.12"
      metric_name = "cis_kms_key_destruction"
      display_name = "[CIS 2.12] Security Alert: Cloud KMS CryptoKey Version Scheduled for Destruction"
      doc_summary  = "A customer-managed cryptographic key (CMEK) was scheduled for permanent destruction. Immediate action is required to prevent data loss."
      severity     = "CRITICAL"
    }
  }

  cis_alerts = local.enable_cis_alerts && local.cis_target_project != null ? {
    for k, v in local.default_cis_definitions : k => {
      key          = k
      project_id   = local.cis_target_project
      control      = v.control
      metric_name  = v.metric_name
      display_name = v.display_name
      doc_summary  = v.doc_summary
      severity     = v.severity
      auto_close   = local.cis_auto_close
      channels     = local.cis_resolved_channels
    }
    if try(local.raw_cis_alerts.exclusions, null) == null || !contains(try(local.raw_cis_alerts.exclusions, []), k)
  } : {}

  # ----------------------------------------------------------------------------
  # 4. Custom Metric Threshold & Log Match Alert Policies
  # ----------------------------------------------------------------------------
  raw_custom_alerts = try(local.raw_config.alert_policies, [])

  custom_alert_policies = {
    for a in local.raw_custom_alerts : a.name => {
      name         = a.name
      project_id   = try(a.project_id, local.default_project_id)
      display_name = try(a.display_name, a.name)
      enabled      = try(a.enabled, true)
      combiner     = try(a.combiner, "OR")
      severity     = try(a.severity, "ERROR")
      auto_close   = try(a.auto_close, "86400s") # 24h default
      user_labels  = merge(local.common_labels, try(a.user_labels, {}))
      
      documentation = try(a.documentation, {
        content   = try(a.documentation_content, "Operational incident triggered. Review Cloud Monitoring logs and affected resources.")
        mime_type = "text/markdown"
      })

      notification_channels = [
        for ch in try(a.notification_channels, []) :
        try(local.channel_lookup[ch], ch)
      ]

      conditions = [
        for idx, cond in try(a.conditions, []) : {
          condition_key = "${a.name}_cond_${idx}"
          display_name  = try(cond.display_name, "${a.name} condition ${idx + 1}")
          type          = lower(try(cond.type, "threshold"))
          
          # Threshold parameters
          filter               = try(cond.filter, null)
          comparison           = try(cond.comparison, "COMPARISON_GT")
          threshold_value      = try(cond.threshold_value, 0)
          duration             = try(cond.duration, "60s")
          alignment_period     = try(cond.alignment_period, "60s")
          per_series_aligner   = try(cond.per_series_aligner, "ALIGN_RATE")
          cross_series_reducer = try(cond.cross_series_reducer, "REDUCE_SUM")
          group_by_fields      = try(cond.group_by_fields, [])
          trigger_count        = try(cond.trigger_count, 1)

          # Log Match parameters
          log_filter = try(cond.log_filter, cond.filter, null)

          # Absent metric parameters
          absent_duration = try(cond.absent_duration, cond.duration, "300s")

          # MQL parameters
          mql_query = try(cond.mql_query, cond.query, null)
        }
      ]
    }
  }
}
