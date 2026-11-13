# ==============================================================================
# 3. Project Factory & Creation
# ==============================================================================
# Provisions GCP projects under target folders with enterprise governance:
# - Standardized project naming with optional prefix and randomized suffix
# - Automatic association with the specified GCP Billing Account
# - Target folder placement (top-level or sub-folder)
# - Metadata labels for FinOps and cost attribution
# - Project deletion protection (PREVENT) to prevent accidental loss
# ==============================================================================

resource "google_project" "projects" {
  for_each = local.projects_map

  name = each.value.name
  project_id = (
    lookup(each.value, "prefix", "") != "" ?
    "${each.value.prefix}-${each.value.name}${lookup(each.value, "random_id", true) ? "-${random_string.project_suffix[each.key].result}" : ""}" :
    "${each.value.name}${lookup(each.value, "random_id", true) ? "-${random_string.project_suffix[each.key].result}" : ""}"
  )
  folder_id       = local.all_folders[each.value.target_folder]
  billing_account = local.config.billing_account_id
  labels          = lookup(each.value, "labels", {})
  deletion_policy = "PREVENT"

  depends_on = [google_folder.top, google_folder.sub]
}
