# ==============================================================================
# HA CLOUD VPN MODULE: IPSEC VPN TUNNELS
# ==============================================================================
# Provisions redundant IPsec VPN tunnels adhering to Google Cloud HA standards.
# Each tunnel binds a specific GCP HA gateway interface to a peer external interface.
# ==============================================================================

resource "google_compute_vpn_tunnel" "tunnel" {
  for_each = local.tunnels_map

  project                         = local.project_id
  region                          = each.value.gateway_region
  name                            = each.value.tunnel_name
  description                     = each.value.description
  vpn_gateway                     = google_compute_ha_vpn_gateway.gateway[each.value.gateway_name].id
  vpn_gateway_interface           = each.value.vpn_gateway_interface
  peer_external_gateway           = each.value.peer_external_gateway_id != null ? each.value.peer_external_gateway_id : google_compute_external_vpn_gateway.external_gateway[each.value.peer_gateway_name].id
  peer_external_gateway_interface = each.value.peer_external_gateway_interface
  shared_secret                   = each.value.shared_secret
  router                          = each.value.router_name
  ike_version                     = each.value.ike_version

  depends_on = [
    google_compute_ha_vpn_gateway.gateway,
    google_compute_external_vpn_gateway.external_gateway
  ]
}
