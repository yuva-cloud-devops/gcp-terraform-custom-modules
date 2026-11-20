module "threat_posture" {
  source           = "../../../secops-infrastructure/threat-posture-infra"
  config_file_path = "${path.module}/threat-posture.yaml"
}
