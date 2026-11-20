module "pki_data_security" {
  source           = "../../..//secops-infrastructure/pki-data-security-infra"
  config_file_path = "./pki-data-security.yaml"
}
