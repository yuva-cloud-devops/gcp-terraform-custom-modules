# ==============================================================================
# 6. Secret Manager IAM Policies & Role Bindings
# ==============================================================================
# Configures authoritative per-member IAM bindings (google_secret_manager_secret_iam_member)
# for individual Secrets, as well as project-level Secret Manager access policies.
# Supports CEL conditions for attribute-based access control (ABAC).
# ==============================================================================

# Secret-level IAM member bindings (Least Privilege Access)
resource "google_secret_manager_secret_iam_member" "secret_members" {
  for_each = local.secret_iam_flat

  project   = each.value.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret_key].secret_id
  role      = each.value.role
  member    = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}

# Project-level Secret Manager administrative and auditor role bindings
resource "google_project_iam_member" "secret_project_members" {
  for_each = local.secret_project_iam_flat

  project = each.value.project_id
  role    = each.value.role
  member  = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}
