# ==============================================================================
# Example: Dashboards & Uptime Infrastructure Deployment
# ==============================================================================

module "dashboards_uptime" {
  source = "../../../secops-infrastructure/dashboards-uptime-infra"

  config_file_path = "${path.module}/dashboards-uptime-config.yaml"
}
