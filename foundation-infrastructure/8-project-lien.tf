# ==============================================================================
# 8. Project Deletion Liens (Hard Deletion Protection)
# ==============================================================================
# Applies a GCP Resource Manager Lien to protect mission-critical projects from
# accidental or unauthorized deletion when 'lien: true' is configured.
# A lien explicitly blocks project deletion via Console, gcloud CLI, or API calls
# until the lien is deliberately removed.
# ==============================================================================

resource "google_resource_manager_lien" "project_lien" {
  for_each = { for k, v in local.projects_map : k => v if lookup(v, "lien", false) }

  parent       = "projects/${google_project.projects[each.key].number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "terraform"
  reason       = "Production protection lien managed by Terraform"
  depends_on   = [google_project.projects]
}
