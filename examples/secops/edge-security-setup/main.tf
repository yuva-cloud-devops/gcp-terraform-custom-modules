module "edge_security" {
  source           = "../../../secops-infrastructure/edge-security-infra"
  config_file_path = "${path.module}/edge-security.yaml"
}
