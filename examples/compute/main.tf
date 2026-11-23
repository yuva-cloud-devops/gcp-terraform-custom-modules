module "compute" {
  source           = "../../compute-infrastructure"
  config_file_path = "./compute-infrastructure.yaml"
}
