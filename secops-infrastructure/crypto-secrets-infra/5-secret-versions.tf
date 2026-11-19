# ==============================================================================
# 5. Secret Manager Secret Versions
# ==============================================================================
# Provisions optional initial secret payloads (Secret Versions) with lifecycle
# deletion policies (DELETE, DISABLE, ABANDON) and enabled/disabled states.
# ==============================================================================

resource "google_secret_manager_secret_version" "versions" {
  for_each = local.secret_versions

  secret          = google_secret_manager_secret.secrets[each.value.secret_key].id
  secret_data     = each.value.secret_data
  enabled         = each.value.enabled
  deletion_policy = each.value.deletion_policy
}
