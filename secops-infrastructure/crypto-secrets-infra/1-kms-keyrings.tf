# ==============================================================================
# 1. Cloud KMS Keyrings
# ==============================================================================
# Provisions Google Cloud KMS Keyrings within specified locations and projects.
# Keyrings serve as organizational and access-boundary containers for crypto keys.
# ==============================================================================

resource "google_kms_key_ring" "keyrings" {
  for_each = local.kms_keyrings

  name     = each.value.name
  location = each.value.location
  project  = each.value.project_id
}
