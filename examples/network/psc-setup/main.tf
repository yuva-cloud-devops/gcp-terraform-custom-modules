# ==============================================================================
# PRIVATE SERVICE CONNECT (PSC) EXAMPLE
# ==============================================================================
# Demonstrates provisioning private endpoints for Google APIs and regional SaaS
# / Producer Service Attachments (e.g. Snowflake, MongoDB Atlas) inside a VPC.
# ==============================================================================

# 1. Base VPC Network for PSC Endpoint Attachment
resource "google_compute_network" "psc_vpc" {
  name                    = "psc-demo-vpc"
  auto_create_subnetworks = false
  description             = "VPC network hosting Private Service Connect endpoints"
}

# 2. Consumer Subnet hosting Regional PSC Endpoints
resource "google_compute_subnetwork" "psc_subnet" {
  name          = "psc-demo-subnet"
  ip_cidr_range = "10.20.1.0/24"
  region        = "asia-south1"
  network       = google_compute_network.psc_vpc.id
  description   = "Consumer subnet for regional PSC service attachment endpoints"
}

# 3. Private Service Connect Custom Module Instantiation
module "psc" {
  source            = "../../../networking-infrastructure/private-service-connect"
  yaml_config_path  = "${path.module}/psc.yaml"
  network_self_link = google_compute_network.psc_vpc.self_link

  depends_on = [google_compute_subnetwork.psc_subnet]
}
