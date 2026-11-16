# ==============================================================================
# HA CLOUD VPN MODULE: CLOUD ROUTER BGP INTERFACES
# ==============================================================================
# Provisions point-to-point BGP interfaces on the target Cloud Router, binding
# each interface to its corresponding IPsec VPN tunnel and link-local IP range.
# ==============================================================================

resource "google_compute_router_interface" "interface" {
  for_each = local.tunnels_map

  project    = local.project_id
  region     = each.value.gateway_region
  name       = each.value.router_interface_name
  router     = each.value.router_name
  ip_range   = each.value.router_interface_ip
  vpn_tunnel = google_compute_vpn_tunnel.tunnel[each.key].name

  depends_on = [google_compute_vpn_tunnel.tunnel]
}
