# ==============================================================================
# VPC NETWORK PEERING MODULE: MAIN RESOURCES
# ==============================================================================
# Provisions bi-directional or uni-directional VPC Network Peering connections
# between Google Cloud Virtual Private Clouds (VPCs).
#
# Key Features:
# 1. Forward Peering (Local VPC -> Remote Peer VPC).
# 2. Automated Reverse Peering (Remote Peer VPC -> Local VPC) for instant ACTIVE status.
# 3. Dynamic route exchange flags (Custom routes, Subnet routes with Public IP).
# 4. Deterministic resource dependencies to eliminate API race conditions.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. FORWARD PEERING (Local Base VPC -> Remote Peer VPC)
# ------------------------------------------------------------------------------
# Initiates peering from the local network to the remote peer network.
# Peering state remains INACTIVE until the remote peer accepts with a matching link.
# ------------------------------------------------------------------------------
resource "google_compute_network_peering" "local_to_peer" {
  for_each = local.peerings_map

  name                                = each.value.name
  network                             = local.local_network_self_link
  peer_network                        = each.value.peer_network_self_link
  export_custom_routes                = lookup(each.value, "export_custom_routes", false)
  import_custom_routes                = lookup(each.value, "import_custom_routes", false)
  export_subnet_routes_with_public_ip = lookup(each.value, "export_subnet_routes_with_public_ip", false)
  import_subnet_routes_with_public_ip = lookup(each.value, "import_subnet_routes_with_public_ip", false)
  stack_type                          = lookup(each.value, "stack_type", null)
}

# ------------------------------------------------------------------------------
# 2. AUTOMATED REVERSE PEERING (Remote Peer VPC -> Local Base VPC)
# ------------------------------------------------------------------------------
# Completes the bi-directional handshake to bring the peering connection into ACTIVE state.
# By default, automatically inverts route import/export flags so communication is symmetric.
# Explicit overrides can be provided via YAML (reverse_export_custom_routes, etc.).
# ------------------------------------------------------------------------------
resource "google_compute_network_peering" "peer_to_local" {
  for_each = local.reverse_peerings_map

  name                                = lookup(each.value, "reverse_name", "${each.value.name}-reverse")
  network                             = each.value.peer_network_self_link
  peer_network                        = local.local_network_self_link
  export_custom_routes                = lookup(each.value, "reverse_export_custom_routes", lookup(each.value, "import_custom_routes", false))
  import_custom_routes                = lookup(each.value, "reverse_import_custom_routes", lookup(each.value, "export_custom_routes", false))
  export_subnet_routes_with_public_ip = lookup(each.value, "reverse_export_subnet_routes_with_public_ip", lookup(each.value, "import_subnet_routes_with_public_ip", false))
  import_subnet_routes_with_public_ip = lookup(each.value, "reverse_import_subnet_routes_with_public_ip", lookup(each.value, "export_subnet_routes_with_public_ip", false))
  stack_type                          = lookup(each.value, "stack_type", null)

  # Prevent concurrent modification race condition on Google Cloud compute networks
  depends_on = [google_compute_network_peering.local_to_peer]
}
