# ==============================================================================
# 6. Project-Level User & Group IAM Bindings
# ==============================================================================
# Assigns IAM roles to users, Google Groups, and service accounts directly on
# specific GCP projects. Supports optional CEL-based IAM conditions for
# fine-grained, time-bound, or context-aware access control.
# ==============================================================================

resource "google_project_iam_member" "users" {
  for_each = { for item in local.project_iam_flat : item.key => item }

  project = google_project.projects[each.value.project_name].project_id
  role    = each.value.role
  member  = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = lookup(condition.value, "description", null)
      expression  = condition.value.expression
    }
  }
}
