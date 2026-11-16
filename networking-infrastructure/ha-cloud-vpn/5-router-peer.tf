# ==============================================================================
# HA CLOUD VPN MODULE: CLOUD ROUTER BGP PEERS
# ==============================================================================
# Establishes eBGP peering sessions with remote on-premises or cloud routers.
# Supports custom route priorities (MED), custom advertised routes, and BFD.
# ==============================================================================

resource "google_compute_router_peer" "peer" {
  for_each = local.tunnels_map

  project                   = local.project_id
  region                    = each.value.gateway_region
  name                      = each.value.router_peer_name
  router                    = each.value.router_name
  interface                 = google_compute_router_interface.interface[each.key].name
  peer_ip_address           = each.value.peer_ip_address
  peer_asn                  = each.value.peer_asn
  advertised_route_priority = each.value.advertised_route_priority
  advertise_mode            = each.value.advertise_mode
  advertised_groups         = each.value.advertised_groups

  # Optional custom advertised IP ranges
  dynamic "advertised_ip_ranges" {
    for_each = each.value.advertised_ip_ranges
    content {
      range       = advertised_ip_ranges.value.range
      description = lookup(advertised_ip_ranges.value, "description", null)
    }
  }

  # Optional Bidirectional Forwarding Detection (BFD) for sub-second failover
  dynamic "bfd" {
    for_each = each.value.bfd != null ? [each.value.bfd] : []
    content {
      session_initialization_mode = lookup(bfd.value, "session_initialization_mode", "ACTIVE")
      min_receive_interval        = lookup(bfd.value, "min_receive_interval", 1000)
      min_transmit_interval       = lookup(bfd.value, "min_transmit_interval", 1000)
      multiplier                  = lookup(bfd.value, "multiplier", 5)
    }
  }

  # Optional custom advertised IP ranges
  dynamic "advertised_ip_ranges" {
    for_each = each.value.advertised_ip_ranges
    content {
      range       = advertised_ip_ranges.value.range
      description = lookup(advertised_ip_ranges.value, "description", null)
    }
  }

  # Optional Bidirectional Forwarding Detection (BFD) for sub-second failover
  dynamic "bfd" {
    for_each = each.value.bfd != null ? [each.value.bfd] : []
    content {
      session_initialization_mode = lookup(bfd.value, "session_initialization_mode", "ACTIVE")
      min_receive_interval        = lookup(bfd.value, "min_receive_interval", 1000)
      min_transmit_interval       = lookup(bfd.value, "min_transmit_interval", 1000)
      multiplier                  = lookup(bfd.value, "multiplier", 5)
    }
  }

  depends_on = [google_compute_router_interface.interface]
}
