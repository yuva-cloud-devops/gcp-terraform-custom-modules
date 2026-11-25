# ==============================================================================
# 4. Metric Threshold & Custom Operational Alert Policies
# ==============================================================================
# Provisions user-defined alert policies supporting metric thresholds, log-match
# alerts, absent metric checks, and MQL queries.
# ==============================================================================

resource "google_monitoring_alert_policy" "custom_alerts" {
  for_each = local.custom_alert_policies

  project      = each.value.project_id
  display_name = each.value.display_name
  combiner     = each.value.combiner
  enabled      = each.value.enabled

  documentation {
    content   = each.value.documentation.content
    mime_type = each.value.documentation.mime_type
  }

  dynamic "conditions" {
    for_each = each.value.conditions
    content {
      display_name = conditions.value.display_name

      # 1. Standard Metric Threshold Condition
      dynamic "condition_threshold" {
        for_each = conditions.value.type == "threshold" ? [1] : []
        content {
          filter          = conditions.value.filter
          comparison      = conditions.value.comparison
          threshold_value = conditions.value.threshold_value
          duration        = conditions.value.duration

          trigger {
            count = conditions.value.trigger_count
          }

          aggregations {
            alignment_period     = conditions.value.alignment_period
            per_series_aligner   = conditions.value.per_series_aligner
            cross_series_reducer = conditions.value.cross_series_reducer
            group_by_fields      = conditions.value.group_by_fields
          }
        }
      }

      # 2. Log Match Condition (Triggers directly on Cloud Logging filter)
      dynamic "condition_matched_log" {
        for_each = conditions.value.type == "log_match" ? [1] : []
        content {
          filter = conditions.value.log_filter
        }
      }

      # 3. Absent Metric Condition (Heartbeat / Missing telemetry)
      dynamic "condition_absent" {
        for_each = conditions.value.type == "absent" ? [1] : []
        content {
          filter   = conditions.value.filter
          duration = conditions.value.absent_duration
          trigger {
            count = 1
          }
        }
      }

      # 4. Monitoring Query Language (MQL) Condition
      dynamic "condition_monitoring_query_language" {
        for_each = conditions.value.type == "mql" ? [1] : []
        content {
          query    = conditions.value.mql_query
          duration = conditions.value.duration
          trigger {
            count = 1
          }
        }
      }
    }
  }

  notification_channels = [
    for ch in each.value.notification_channels :
    try(google_monitoring_notification_channel.channels[ch].id, ch)
  ]

  alert_strategy {
    auto_close = each.value.auto_close
  }

  user_labels = each.value.user_labels
}
