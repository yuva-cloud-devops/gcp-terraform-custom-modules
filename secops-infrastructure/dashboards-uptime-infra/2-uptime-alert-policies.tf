# ==============================================================================
# 2. Automated Uptime & SSL Expiration Alert Policies
# ==============================================================================
# Automatically binds incident alert policies to synthetic uptime probes for
# endpoint failure detection and proactive TLS/SSL certificate expiration warnings.
# ==============================================================================

# ------------------------------------------------------------------------------
# 2A. Uptime Check Outage Alert Policies
# ------------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "uptime_failure_alerts" {
  for_each = local.uptime_failure_alerts

  project      = each.value.project_id
  display_name = each.value.display_name
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "### Service Outage Detected: ${each.value.display_name}\n\n${each.value.doc_summary}\n\n#### Immediate Actions:\n1. Verify service health and endpoint logs in Cloud Run / GKE / Compute Engine.\n2. Check Cloud Armor and VPC firewall rules for accidental ingress blocks.\n3. Verify DNS resolution and SSL certificate validity."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Uptime Check Health - ${each.value.uptime_check_name}"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.uptime_checks[each.key].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.project_id"]
      }
    }
  }

  notification_channels = each.value.notification_channels

  alert_strategy {
    auto_close = "1800s" # Auto close after 30m of recovery
  }

  user_labels = merge(local.common_labels, {
    category = "uptime_outage"
    severity = "critical"
  })
}

# ------------------------------------------------------------------------------
# 2B. SSL/TLS Certificate Expiration Alert Policies
# ------------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "ssl_expiry_alerts" {
  for_each = local.ssl_cert_alerts

  project      = each.value.project_id
  display_name = each.value.display_name
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "### SSL/TLS Certificate Expiring: ${each.value.display_name}\n\n${each.value.doc_summary}\n\n#### Immediate Remediation:\n1. Check Google Certificate Manager or Let's Encrypt / DigiCert renewal pipelines.\n2. Verify DNS authorization challenges if using managed certificates.\n3. Update load balancer target proxies with the renewed TLS certificate."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Time Until Certificate Expiry < ${each.value.ssl_expiry_days} Days"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.uptime_checks[each.key].uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = each.value.threshold_seconds
      duration        = "300s"
      trigger {
        count = 1
      }
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MIN"
        cross_series_reducer = "REDUCE_MIN"
      }
    }
  }

  notification_channels = each.value.notification_channels

  alert_strategy {
    auto_close = "604800s" # 7 days
  }

  user_labels = merge(local.common_labels, {
    category = "ssl_expiration"
    severity = "warning"
  })
}
