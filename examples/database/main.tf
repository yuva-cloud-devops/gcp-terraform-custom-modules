module "database" {
  source           = "../../database-infrastructure"
  config_file_path = "./database-infrastructure.yaml"
}
