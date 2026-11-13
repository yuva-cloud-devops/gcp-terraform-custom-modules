# ==============================================================================
# 9. Cryptographic Resource Tag Bindings (ABAC & Governance)
# ==============================================================================
# Attaches organization-level Resource Manager Tag Values to created GCP projects.
# Cryptographic tags provide tamper-proof metadata used for Attribute-Based Access
# Control (ABAC), fine-grained IAM conditions, and Organization Policy enforcement.
# ==============================================================================

resource "google_tags_tag_binding" "project_tags" {
  for_each = { for item in local.project_tag_bindings_flat : item.key => item }

  parent     = "//cloudresourcemanager.googleapis.com/projects/${google_project.projects[each.value.project_name].number}"
  tag_value  = google_tags_tag_value.values[each.value.tag_key_val].id
  depends_on = [google_project.projects, google_tags_tag_value.values]
}
