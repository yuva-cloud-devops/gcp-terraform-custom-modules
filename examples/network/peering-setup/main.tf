# ==============================================================================
# VPC NETWORK PEERING EXAMPLE: MAIN TOPOLOGY
# ==============================================================================
# Demonstrates setting up a bi-directional VPC Network Peering connection
# between a Hub VPC and a Spoke/Analytics VPC with automated reverse handshake
# and dynamic custom route exchanges.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Base / Hub VPC Network and Subnet
# ------------------------------------------------------------------------------
resource "google_compute_network" "hub_vpc" {
  name                    = "peering-demo-hub-vpc"
  auto_create_subnetworks = false
  description             = "Central Hub VPC initiating peering connections"
}

resource "google_compute_subnetwork" "hub_subnet" {
  name          = "peering-demo-hub-subnet"
  ip_cidr_range = "10.10.1.0/24"
  region        = "asia-south1"
  network       = google_compute_network.hub_vpc.id
  description   = "Workload subnet within Hub VPC"
}

# ------------------------------------------------------------------------------
# 2. Peer / Spoke VPC Network and Subnet
# ------------------------------------------------------------------------------
resource "google_compute_network" "spoke_vpc" {
  name                    = "peering-demo-spoke-vpc"
  auto_create_subnetworks = false
  description             = "Spoke / Analytics VPC targeted by peering connection"
}

resource "google_compute_subnetwork" "spoke_subnet" {
  name          = "peering-demo-spoke-subnet"
  ip_cidr_range = "10.20.1.0/24"
  region        = "asia-south1"
  network       = google_compute_network.spoke_vpc.id
  description   = "Analytics workload subnet within Spoke VPC"
}

# ------------------------------------------------------------------------------
# 3. VPC Network Peering Custom Module Instantiation
# ------------------------------------------------------------------------------
module "vpc_peering" {
  source                  = "../../../networking-infrastructure/network-peering"
  yaml_config_path        = "${path.module}/peering.yaml"
  local_network_self_link = google_compute_network.hub_vpc.self_link

  # Dynamically link the newly provisioned spoke VPC without hardcoding URIs
  peer_network_overrides = {
    "peering-hub-to-spoke" = google_compute_network.spoke_vpc.self_link
  }

  depends_on = [
    google_compute_subnetwork.hub_subnet,
    google_compute_subnetwork.spoke_subnet
  ]
}
