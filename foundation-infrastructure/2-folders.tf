# ==============================================================================
# 2. Resource Hierarchy Folders (Top-Level & Sub-Folders)
# ==============================================================================
# Provisions a multi-tier folder hierarchy to organize projects according to
# organizational units, environments, and business domains.
# Configurable 'deletion_protection' (default: false) controls whether Terraform
# can destroy or recreate folders during infrastructure teardowns.
# ==============================================================================

# ------------------------------------------------------------------------------
# 2.1 Top-Level Folders (Direct Children of GCP Organization)
# ------------------------------------------------------------------------------
resource "google_folder" "top" {
  for_each            = local.top_level_folders_map
  display_name        = each.value.name
  parent              = "organizations/${local.config.organization_id}"
  deletion_protection = lookup(each.value, "deletion_protection", false)
}

# ------------------------------------------------------------------------------
# 2.2 Sub-Folders (Children of Specified Top-Level Folders)
# ------------------------------------------------------------------------------
resource "google_folder" "sub" {
  for_each            = local.sub_folders_map
  display_name        = each.value.name
  parent              = google_folder.top[each.value.parent].name
  deletion_protection = lookup(each.value, "deletion_protection", false)
}
