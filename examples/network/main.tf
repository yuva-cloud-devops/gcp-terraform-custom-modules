module "networking" {
  source           = "../networking-infrastructure/vpc-subnet-router-nat-firewall"
  config_file_path = "${path.module}/network-config.yaml"
}

