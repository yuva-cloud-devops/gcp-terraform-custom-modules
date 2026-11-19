# ==============================================================================
# 2. Cloud KMS Crypto Keys
# ==============================================================================
# Provisions symmetric and asymmetric cryptographic keys within KMS Keyrings.
# Supports automatic rotation schedules, version templates (HSM / SOFTWARE),
# destruction duration policies, and purpose-specific algorithms.
# ==============================================================================

resource "google_kms_crypto_key" "keys" {
  for_each = local.kms_keys

  name                       = each.value.name
  key_ring                   = google_kms_key_ring.keyrings[each.value.keyring_key].id
  purpose                    = each.value.purpose
  destroy_scheduled_duration = each.value.destroy_scheduled_duration
  skip_initial_version_creation = each.value.skip_initial_version_creation
  labels                     = each.value.labels

  # Automatic rotation is only permitted on symmetric ENCRYPT_DECRYPT or RAW_ENCRYPT_DECRYPT keys
  rotation_period = (
    contains(["ENCRYPT_DECRYPT", "RAW_ENCRYPT_DECRYPT"], each.value.purpose) ?
    each.value.rotation_period : null
  )

  dynamic "version_template" {
    for_each = each.value.version_template != null ? [each.value.version_template] : []
    content {
      algorithm        = version_template.value.algorithm
      protection_level = version_template.value.protection_level
    }
  }
}
