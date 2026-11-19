# ==============================================================================
# CRYPTO & SECRETS INFRASTRUCTURE EXAMPLE: OUTPUTS
# ==============================================================================

output "keyrings" {
  description = "Provisioned KMS keyrings."
  value       = module.crypto_secrets.keyrings
}

output "keyring_ids" {
  description = "Map of KMS keyring names to full resource IDs."
  value       = module.crypto_secrets.keyring_ids
}

output "keys" {
  description = "Provisioned KMS CryptoKeys."
  value       = module.crypto_secrets.keys
}

output "key_ids" {
  description = "Map of composite keys to full CryptoKey resource IDs."
  value       = module.crypto_secrets.key_ids
}

output "key_ids_by_name" {
  description = "Convenience lookup of short key names to full CryptoKey resource IDs."
  value       = module.crypto_secrets.key_ids_by_name
}

output "secrets" {
  description = "Provisioned Secret Manager secrets."
  value       = module.crypto_secrets.secrets
}

output "secret_ids" {
  description = "Map of secret IDs to full resource IDs."
  value       = module.crypto_secrets.secret_ids
}

output "secret_versions" {
  description = "Metadata of provisioned secret versions (payloads redacted)."
  value       = module.crypto_secrets.secret_versions
}

output "summary" {
  description = "Summary counts of provisioned security resources."
  value       = module.crypto_secrets.summary
}
