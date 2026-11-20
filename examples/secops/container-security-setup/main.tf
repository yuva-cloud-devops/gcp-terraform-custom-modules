module "container_security" {
  source           = "../../../secops-infrastructure/container-security-infra"
  config_file_path = "./container-security.yaml"
}
