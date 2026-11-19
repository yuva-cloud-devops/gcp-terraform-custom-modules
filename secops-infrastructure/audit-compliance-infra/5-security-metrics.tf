# ==============================================================================
# 5. CIS Benchmark & Security Log-Based Metrics
# ==============================================================================
# Provisions Cloud Logging log-based metrics aligned with CIS Google Cloud Platform
# Foundations Benchmark Section 2 (Logging & Monitoring) and custom SecOps filters.
# These metrics feed into Cloud Monitoring alerts and SIEM correlation rules.
# ==============================================================================

resource "google_logging_metric" "security_metrics" {
  for_each = {
    for k, v in local.all_metrics : k => v
    if v.project_id != null
  }

  name        = each.value.name
  project     = each.value.project_id
  description = each.value.description
  filter      = each.value.filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}
