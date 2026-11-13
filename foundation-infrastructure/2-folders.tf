# ==============================================================================
# 2. Resource Hierarchy Folders (Top-Level & Sub-Folders)
# ==============================================================================
# Provisions a multi-tier folder hierarchy to organize projects according to
# organizational units, environments, and business domains.
# ==============================================================================

# ------------------------------------------------------------------------------
# 2.1 Top-Level Folders (Direct Children of GCP Organization)
# ------------------------------------------------------------------------------
resource "google_folder" "top" {
  for_each     = { for f in lookup(local.config, "top_level_folders", []) : f.name => f }
  display_name = each.value.name
  parent       = "organizations/${local.config.organization_id}"
}

# ------------------------------------------------------------------------------
# 2.2 Sub-Folders (Children of Specified Top-Level Folders)
# ------------------------------------------------------------------------------
resource "google_folder" "sub" {
  for_each     = { for f in lookup(local.config, "sub_folders", []) : f.name => f }
  display_name = each.value.name
  parent       = google_folder.top[each.value.parent].name
}
