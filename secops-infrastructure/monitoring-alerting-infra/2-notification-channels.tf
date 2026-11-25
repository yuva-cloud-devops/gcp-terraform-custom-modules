# ==============================================================================
# 2. Notification Channels
# ==============================================================================
# Provisions notification channels (Email, Slack, PagerDuty, Webhooks, Pub/Sub)
# for routing SecOps compliance and operational incidents.
# ==============================================================================

resource "google_monitoring_notification_channel" "channels" {
  for_each = local.notification_channels

  project      = each.value.project_id
  display_name = each.value.display_name
  type         = each.value.type
  description  = each.value.description
  enabled      = each.value.enabled
  labels       = each.value.labels
  user_labels  = each.value.user_labels

  dynamic "sensitive_labels" {
    for_each = length(keys(each.value.sensitive_labels)) > 0 ? [each.value.sensitive_labels] : []
    content {
      auth_token  = try(sensitive_labels.value.auth_token, null)
      service_key = try(sensitive_labels.value.service_key, null)
      password    = try(sensitive_labels.value.password, null)
    }
  }
}
