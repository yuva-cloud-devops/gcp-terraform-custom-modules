module "foundation_infrastructure" {
  source           = "../../foundation-infrastructure"
  yaml_config_path = "${path.module}/hierarchy.yaml"
}
