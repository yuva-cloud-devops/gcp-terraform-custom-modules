# ==============================================================================
# CRYPTO & SECRETS INFRASTRUCTURE: OUTPUTS
# ==============================================================================

# ------------------------------------------------------------------------------
# Cloud KMS Outputs
# ------------------------------------------------------------------------------

output "keyrings" {
  description = "Detailed map of provisioned Google Cloud KMS keyrings."
  value = {
    for k, v in google_kms_key_ring.keyrings : k => {
      id       = v.id
      name     = v.name
      location = v.location
      project  = v.project
    }
  }
}

output "keyring_ids" {
  description = "Map of KMS keyring names to their full GCP resource IDs."
  value       = { for k, v in google_kms_key_ring.keyrings : k => v.id }
}

output "keys" {
  description = "Detailed map of provisioned KMS CryptoKeys indexed by composite key '<keyring_name>/<key_name>'."
  value = {
    for k, v in google_kms_crypto_key.keys : k => {
      id                         = v.id
      name                       = v.name
      key_ring                   = v.key_ring
      purpose                    = v.purpose
      rotation_period            = v.rotation_period
      destroy_scheduled_duration = v.destroy_scheduled_duration
      labels                     = v.labels
    }
  }
}

output "key_ids" {
  description = "Map of composite keys '<keyring_name>/<key_name>' to their full KMS CryptoKey resource IDs."
  value       = { for k, v in google_kms_crypto_key.keys : k => v.id }
}

output "key_ids_by_name" {
  description = "Convenience lookup map of key names directly to their full KMS CryptoKey resource IDs."
  value       = { for k, v in google_kms_crypto_key.keys : v.name => v.id }
}

# ------------------------------------------------------------------------------
# Secret Manager Outputs
# ------------------------------------------------------------------------------

output "secrets" {
  description = "Detailed map of provisioned Secret Manager secrets."
  value = {
    for k, v in google_secret_manager_secret.secrets : k => {
      id          = v.id
      name        = v.name
      secret_id   = v.secret_id
      project     = v.project
      labels      = v.labels
      annotations = v.annotations
    }
  }
}

output "secret_ids" {
  description = "Map of secret IDs to their full Secret Manager resource IDs ('projects/{{project}}/secrets/{{secret_id}}')."
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.id }
}

output "secret_names" {
  description = "Map of secret IDs to their Secret Manager resource names ('projects/{{project_number}}/secrets/{{secret_id}}')."
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.name }
}

output "secret_versions" {
  description = "Map of provisioned initial secret version metadata (sensitive payloads are redacted)."
  value = {
    for k, v in google_secret_manager_secret_version.versions : k => {
      id              = v.id
      name            = v.name
      version         = v.version
      enabled         = v.enabled
      deletion_policy = v.deletion_policy
    }
  }
}

# ------------------------------------------------------------------------------
# Module Summary
# ------------------------------------------------------------------------------

output "summary" {
  description = "Statistical summary of provisioned cryptographic and secrets infrastructure."
  value = {
    total_keyrings        = length(google_kms_key_ring.keyrings)
    total_keys            = length(google_kms_crypto_key.keys)
    total_secrets         = length(google_secret_manager_secret.secrets)
    total_secret_versions = length(google_secret_manager_secret_version.versions)
  }
}
