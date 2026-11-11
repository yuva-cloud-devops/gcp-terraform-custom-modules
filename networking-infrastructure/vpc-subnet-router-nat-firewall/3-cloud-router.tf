# ==============================================================================
# 3. Cloud Routers & BGP (Reference: terraform-google-modules/cloud-router/google)
# ==============================================================================

resource "google_compute_router" "routers" {
  for_each = local.routers

  project                       = local.project_id
  name                          = each.value.name
  region                        = each.value.region
  network                       = google_compute_network.vpcs[each.value.vpc_name].id
  description                   = each.value.description
  encrypted_interconnect_router = each.value.encrypted_interconnect_router

  # Detailed BGP Configuration Block
  dynamic "bgp" {
    for_each = each.value.bgp != null ? [each.value.bgp] : []
    content {
      asn                = bgp.value.asn
      advertise_mode     = bgp.value.advertise_mode
      advertised_groups  = bgp.value.advertised_groups
      keepalive_interval = bgp.value.keepalive_interval
      identifier_range   = bgp.value.identifier_range

      dynamic "advertised_ip_ranges" {
        for_each = bgp.value.advertised_ip_ranges
        content {
          range       = advertised_ip_ranges.value.range
          description = advertised_ip_ranges.value.description
        }
      }
    }
  }
}

# Optional Cloud Router Interfaces (for VPN / Interconnect)
resource "google_compute_router_interface" "interfaces" {
  for_each = local.router_interfaces

  project                 = local.project_id
  name                    = each.value.name
  router                  = google_compute_router.routers[each.value.router_name].name
  region                  = each.value.region
  ip_range                = each.value.ip_range
  vpn_tunnel              = each.value.vpn_tunnel
  interconnect_attachment = each.value.interconnect_attachment
  redundant_interface     = each.value.redundant_interface
  subnetwork              = each.value.subnetwork
  private_ip_address      = each.value.private_ip_address
}

# Optional Cloud Router BGP Peers
resource "google_compute_router_peer" "peers" {
  for_each = local.router_peers

  project                   = local.project_id
  name                      = each.value.name
  router                    = google_compute_router.routers[each.value.router_name].name
  region                    = each.value.region
  interface                 = each.value.interface
  peer_asn                  = each.value.peer_asn
  ip_address                = each.value.ip_address
  peer_ip_address           = each.value.peer_ip_address
  advertised_route_priority = each.value.advertised_route_priority
  advertise_mode            = each.value.advertise_mode
  advertised_groups         = each.value.advertised_groups
  enable                    = each.value.enable

  dynamic "advertised_ip_ranges" {
    for_each = each.value.advertised_ip_ranges
    content {
      range       = advertised_ip_ranges.value.range
      description = advertised_ip_ranges.value.description
    }
  }

  dynamic "bfd" {
    for_each = each.value.bfd != null ? [each.value.bfd] : []
    content {
      session_initialization_mode = try(bfd.value.session_initialization_mode, "PASSIVE")
      min_transmit_interval       = try(bfd.value.min_transmit_interval, 1000)
      min_receive_interval        = try(bfd.value.min_receive_interval, 1000)
      multiplier                  = try(bfd.value.multiplier, 5)
    }
  }

  depends_on = [google_compute_router_interface.interfaces]
}
