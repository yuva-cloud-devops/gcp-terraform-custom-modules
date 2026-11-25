# ==============================================================================
# 1. Multi-Project Metric Scopes
# ==============================================================================
# Centrally links monitored projects into a single scoping project for
# consolidated, cross-project Cloud Monitoring, alert policies, and dashboards.
# ==============================================================================

resource "google_monitoring_monitored_project" "monitored_projects" {
  for_each = local.monitored_projects

  metrics_scope = each.value.scoping_project
  name          = each.value.monitored_project
}
