# ==============================================================================
# 7. Custom Workload Service Accounts & Role Assignments
# ==============================================================================
# Provisions dedicated, least-privilege service accounts per project for workloads,
# applications, and CI/CD pipelines, and assigns required IAM roles to each.
# ==============================================================================

# ------------------------------------------------------------------------------
# 7.1 Dedicated Workload Service Accounts Creation
# ------------------------------------------------------------------------------
resource "google_service_account" "sa" {
  for_each = { for item in local.custom_sas_flat : item.key => item }

  project      = google_project.projects[each.value.project_name].project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name

  depends_on = [google_project.projects]
}

# ------------------------------------------------------------------------------
# 7.2 Project-Level IAM Roles for Custom Service Accounts
# ------------------------------------------------------------------------------
resource "google_project_iam_member" "sa_roles" {
  for_each = { for item in local.custom_sa_roles_flat : item.key => item }

  project = google_project.projects[each.value.project_name].project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.sa["${each.value.project_name}-${each.value.account_id}"].email}"
}
