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
