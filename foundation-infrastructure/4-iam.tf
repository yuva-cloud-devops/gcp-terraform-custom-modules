# ==============================================================================
# 4. Folder IAM Bindings & Project Security Hardening
# ==============================================================================
# Implements governance controls:
# 1. Folder IAM member bindings with optional Common Expression Language (CEL) conditions
# 2. Project Factory security baseline: Deprivilege the default Compute Engine SA
# ==============================================================================

# ------------------------------------------------------------------------------
# 4.1 Folder IAM Member Bindings (with Optional CEL Conditions)
# ------------------------------------------------------------------------------
resource "google_folder_iam_member" "folders" {
  for_each = { for item in local.folder_iam_flat : item.key => item }

  folder = local.all_folders[each.value.folder_name]
  role   = each.value.role
  member = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}

# ------------------------------------------------------------------------------
# 4.2 Security Baseline: Deprivilege Default Compute Engine Service Account
# ------------------------------------------------------------------------------
# By default, GCP grants the broad 'Editor' (roles/editor) role to the default
# Compute Engine service account ({project_number}-compute@developer.gserviceaccount.com).
# Setting action = "DEPRIVILEGE" strips this overly permissive role to follow least privilege.
resource "google_project_default_service_accounts" "deprivilege" {
  for_each = { for k, v in local.projects_map : k => v if lookup(v, "deprivilege_default_sa", true) }

  project    = google_project.projects[each.key].project_id
  action     = "DEPRIVILEGE"
  depends_on = [google_project_service.apis]
}
