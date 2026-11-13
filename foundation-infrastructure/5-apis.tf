# ==============================================================================
# 5. Project API & Service Enablement
# ==============================================================================
# Dynamically activates GCP APIs and services required for project workloads.
# Services are preserved upon module destruction to prevent accidental disruption
# (disable_on_destroy = false, disable_dependent_services = false).
# ==============================================================================

resource "google_project_service" "apis" {
  for_each                   = { for item in local.project_apis_flat : item.key => item }
  project                    = google_project.projects[each.value.project_name].project_id
  service                    = each.value.api
  disable_on_destroy         = false
  disable_dependent_services = false
}
