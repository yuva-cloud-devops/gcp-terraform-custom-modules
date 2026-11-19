# ==============================================================================
# 4. Secret Manager Secrets
# ==============================================================================
# Provisions Google Secret Manager Secrets with enterprise replication modes,
# Customer-Managed Encryption Keys (CMEK), rotation policies, TTL expirations,
# and Pub/Sub notification topics for secret lifecycle events.
# ==============================================================================

resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets

  secret_id   = each.value.secret_id
  project     = each.value.project_id
  labels      = each.value.labels
  annotations = each.value.annotations

  expire_time         = each.value.expire_time
  ttl                 = each.value.ttl
  version_destroy_ttl = each.value.version_destroy_ttl

  replication {
    # Automatic global replication with optional CMEK encryption
    dynamic "auto" {
      for_each = contains(["automatic", "auto"], each.value.replication_type) ? [1] : []
      content {
        dynamic "customer_managed_encryption" {
          for_each = each.value.resolved_kms_key_name != null ? [1] : []
          content {
            kms_key_name = each.value.resolved_kms_key_name
          }
        }
      }
    }

    # User-managed regional/multi-regional replicas with optional per-replica CMEK
    dynamic "user_managed" {
      for_each = each.value.replication_type == "user_managed" ? [1] : []
      content {
        dynamic "replicas" {
          for_each = each.value.user_managed_replicas
          content {
            location = replicas.value.location
            dynamic "customer_managed_encryption" {
              for_each = replicas.value.resolved_kms_key_name != null ? [1] : []
              content {
                kms_key_name = replicas.value.resolved_kms_key_name
              }
            }
          }
        }
      }
    }
  }

  # Automated secret rotation schedule
  dynamic "rotation" {
    for_each = each.value.rotation != null ? [each.value.rotation] : []
    content {
      rotation_period    = rotation.value.rotation_period
      next_rotation_time = rotation.value.next_rotation_time
    }
  }

  # Eventarc / Cloud Pub/Sub rotation and event notification topics
  dynamic "topics" {
    for_each = each.value.topics
    content {
      name = topics.value.name
    }
  }

  # Ensure KMS IAM bindings and Secret Manager Service Agent CMEK permissions
  # are fully active in GCP before attempting to create CMEK-wrapped secrets
  depends_on = [
    google_kms_crypto_key_iam_member.secret_manager_cmek,
    google_kms_crypto_key_iam_member.key_members
  ]
}
