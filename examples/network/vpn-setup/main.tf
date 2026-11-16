# ==============================================================================
# HA CLOUD VPN EXAMPLE: MAIN TOPOLOGY
# ==============================================================================
# Demonstrates provisioning an end-to-end, resilient hybrid network connection
# featuring a Base VPC, Subnet, Cloud Router, and HA Cloud VPN Gateway with dual
# redundant active-active IPsec tunnels and eBGP dynamic routing.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Base VPC Network and Subnet
# ------------------------------------------------------------------------------
resource "google_compute_network" "vpn_vpc" {
  name                    = "vpn-demo-vpc"
  auto_create_subnetworks = false
  description             = "Base VPC network hosting hybrid HA VPN infrastructure"
}

resource "google_compute_subnetwork" "vpn_subnet" {
  name          = "vpn-demo-subnet"
  ip_cidr_range = "10.50.1.0/24"
  region        = "asia-south1"
  network       = google_compute_network.vpn_vpc.id
  description   = "Workload subnet routed to on-premises network"
}

# ------------------------------------------------------------------------------
# 2. Cloud Router for BGP Peering
# ------------------------------------------------------------------------------
resource "google_compute_router" "vpn_router" {
  name        = "cr-vpn-demo"
  region      = "asia-south1"
  network     = google_compute_network.vpn_vpc.name
  description = "Cloud Router managing dynamic eBGP routing for HA VPN tunnels"

  bgp {
    asn                = 65000
    advertise_mode     = "DEFAULT"
    keepalive_interval = 20
  }
}

# ------------------------------------------------------------------------------
# 3. HA Cloud VPN Custom Module Instantiation
# ------------------------------------------------------------------------------
module "ha_vpn" {
  source            = "../../../networking-infrastructure/ha-cloud-vpn"
  yaml_config_path  = "${path.module}/vpn.yaml"
  network_self_link = google_compute_network.vpn_vpc.self_link
  router_name       = google_compute_router.vpn_router.name

  depends_on = [
    google_compute_network.vpn_vpc,
    google_compute_subnetwork.vpn_subnet,
    google_compute_router.vpn_router
  ]
}
