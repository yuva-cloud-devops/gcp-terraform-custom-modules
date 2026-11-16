# 2. DYNAMIC YAML-DRIVEN SHARED VPC
module "shared_vpc" {
  source           = "../../../networking-infrastructure/shared-vpc"
  yaml_config_path = "${path.module}/shared_vpc.yaml"

  # Ensures base subnets exist before attempting IAM attachments
  depends_on = [module.vpc-networking]
}
