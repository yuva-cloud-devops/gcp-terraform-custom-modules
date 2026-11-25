# ==============================================================================
# Example: Monitoring & Alerting Infrastructure Deployment
# ==============================================================================

module "monitoring_alerting" {
  source = "../../../secops-infrastructure/monitoring-alerting-infra"

  config_file_path = "${path.module}/monitoring-config.yaml"
}
