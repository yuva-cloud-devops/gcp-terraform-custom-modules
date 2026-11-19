# ==============================================================================
# Example: Zero-Trust Security Infrastructure (WIF & IAP) Main Deployment
# ==============================================================================

module "zero_trust" {
  source = "../../../secops-infrastructure/zero-trust-security-infra"

  config_file_path = "${path.module}/zero-trust.yaml"
}
