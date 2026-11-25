# ==============================================================================
# 3. CIS GCP Benchmark v3 Security Alerts
# ==============================================================================
# Automatically creates incident alert policies wired directly to the 9 CIS
# Foundations Benchmark Section 2 log-based security metrics provisioned in
# 'audit-compliance-infra' (controls 2.4 - 2.12).
# ==============================================================================

resource "google_monitoring_alert_policy" "cis_alerts" {
  for_each = local.cis_alerts

  project      = each.value.project_id
  display_name = each.value.display_name
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "### ${each.value.control}: ${each.value.display_name}\n\n**Severity**: `${each.value.severity}`\n\n${each.value.doc_summary}\n\n#### Immediate Remediation Steps:\n1. Open Cloud Logging to identify caller IP, authenticated user, and method call.\n2. Review audit logs for anomalous privilege escalation or unauthorized perimeter drift.\n3. Roll back unauthorized changes or engage your Security Operations incident team."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = each.value.display_name
    condition_threshold {
      filter          = "resource.type = \"global\" AND metric.type = \"logging.googleapis.com/user/${each.value.metric_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [
    for ch in each.value.channels :
    try(google_monitoring_notification_channel.channels[ch].id, ch)
  ]

  alert_strategy {
    auto_close = each.value.auto_close
  }

  user_labels = merge(local.common_labels, {
    compliance_framework = "cis_gcp_benchmark_v3"
    control_id           = replace(lower(each.value.control), " ", "_")
    severity             = lower(each.value.severity)
  })
}
