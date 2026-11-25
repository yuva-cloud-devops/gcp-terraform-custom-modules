# ==============================================================================
# 1. Synthetic Uptime Checks
# ==============================================================================
# Provisions multi-region synthetic uptime check probes (HTTP, HTTPS, TCP)
# to continuously verify endpoint availability, response latency, and SSL certs.
# ==============================================================================

resource "google_monitoring_uptime_check_config" "uptime_checks" {
  for_each = local.uptime_checks

  project          = each.value.project_id
  display_name     = each.value.display_name
  timeout          = each.value.timeout
  period           = each.value.period
  selected_regions = each.value.selected_regions
  checker_type     = each.value.checker_type

  dynamic "http_check" {
    for_each = each.value.protocol == "HTTP" || each.value.protocol == "HTTPS" ? [1] : []
    content {
      request_method = each.value.request_method
      path           = each.value.path
      port           = each.value.port
      use_ssl        = each.value.protocol == "HTTPS"
      validate_ssl   = each.value.validate_ssl
      headers        = each.value.headers
      body           = each.value.body
      content_type   = each.value.content_type

      dynamic "accepted_response_status_codes" {
        for_each = each.value.status_classes
        content {
          status_class = accepted_response_status_codes.value
        }
      }
    }
  }

  dynamic "tcp_check" {
    for_each = each.value.protocol == "TCP" ? [1] : []
    content {
      port = each.value.port
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = each.value.project_id
      host       = each.value.host
    }
  }

  dynamic "content_matchers" {
    for_each = each.value.content_matchers
    content {
      content = content_matchers.value.content
      matcher = content_matchers.value.matcher
    }
  }
}
