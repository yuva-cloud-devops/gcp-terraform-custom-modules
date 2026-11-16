# ==============================================================================
# CLOUD DNS ARCHITECTURE EXAMPLE
# ==============================================================================
# Demonstrates provisioning private authoritative DNS zones, hybrid DNS
# forwarding to on-premises resolvers, and restricted Google APIs routing
# bound to a target VPC network.
# ==============================================================================

# 1. Base VPC Network for DNS Binding
resource "google_compute_network" "dns_vpc" {
  name                    = "dns-demo-vpc"
  auto_create_subnetworks = false
  description             = "VPC network for Cloud DNS private zone resolution"
}

# 2. Cloud DNS Custom Module Instantiation
module "cloud_dns" {
  source            = "../../../networking-infrastructure/cloud-dns"
  yaml_config_path  = "${path.module}/dns.yaml"
  network_self_link = google_compute_network.dns_vpc.self_link
}
