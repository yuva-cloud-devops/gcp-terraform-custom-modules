# ==============================================================================
# Example: Audit & Compliance Infrastructure Main Deployment
# ==============================================================================

module "audit_compliance" {
  source = "../../../secops-infrastructure/audit-compliance-infra"

  config_file_path = "${path.module}/audit-compliance.yaml"
}
