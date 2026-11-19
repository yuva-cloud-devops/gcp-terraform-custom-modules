# ==============================================================================
# 3. Cloud KMS IAM Policies & Role Bindings
# ==============================================================================
# Configures authoritative per-member IAM bindings (google_kms_*_iam_member)
# for Keyrings, CryptoKeys, and project-level KMS administrative roles.
# Supports CEL conditions for attribute-based access control.
# ==============================================================================

# Keyring-level IAM member bindings
resource "google_kms_key_ring_iam_member" "keyring_members" {
  for_each = local.kms_keyring_iam_flat

  key_ring_id = google_kms_key_ring.keyrings[each.value.keyring_key].id
  role        = each.value.role
  member      = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}

# CryptoKey-level IAM member bindings (Least Privilege & CMEK Delegation)
resource "google_kms_crypto_key_iam_member" "key_members" {
  for_each = local.kms_key_iam_flat

  crypto_key_id = google_kms_crypto_key.keys[each.value.key_composite_key].id
  role          = each.value.role
  member        = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}

# Project-level KMS administrative and operational IAM member bindings
resource "google_project_iam_member" "kms_project_members" {
  for_each = local.kms_project_iam_flat

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

# ------------------------------------------------------------------------------
# Automated Secret Manager Service Agent CMEK Delegation
# ------------------------------------------------------------------------------
# Ensures the Secret Manager service identity exists and has Decrypt/Encrypt
# permissions on the KMS keys used for Secret Manager envelope encryption.
# ------------------------------------------------------------------------------

data "google_project" "cmek_projects" {
  for_each   = length(local.secret_manager_cmek_grants) > 0 ? toset(local.distinct_project_ids) : toset([])
  project_id = each.value
}

resource "google_kms_crypto_key_iam_member" "secret_manager_cmek" {
  for_each = local.secret_manager_cmek_grants

  crypto_key_id = each.value.crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.cmek_projects[each.value.project_id].number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}
