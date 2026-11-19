# ==============================================================================
# CRYPTO & SECRETS INFRASTRUCTURE EXAMPLE
# ==============================================================================

module "crypto_secrets" {
  source           = "../../../secops-infrastructure/crypto-secrets-infra"
  config_file_path = "${path.module}/crypto-secrets.yaml"
}
