# ==============================================================================
# HA CLOUD VPN MODULE: LOCALS & CONFIGURATION PARSER
# ==============================================================================
# Decodes the YAML configuration, extracts gateway topologies, resolves unique
# external peer gateways, and flattens tunnel and BGP peering configurations.
# ==============================================================================

locals {
  # 1. Decode YAML configuration file
  raw_config = yamldecode(file(var.yaml_config_path))

  # 2. Global settings with fallbacks between variables and YAML
  project_id = trimspace(
    var.project_id != "" ? var.project_id : lookup(local.raw_config, "project_id", "")
  )

  default_region = trimspace(
    var.default_region != "" ? var.default_region : lookup(local.raw_config, "default_region", "asia-south1")
  )

  default_router_name = trimspace(
    var.router_name != "" ? var.router_name : lookup(local.raw_config, "default_router_name", "")
  )

  network_self_link = trimspace(
    var.network_self_link != "" ? var.network_self_link : lookup(local.raw_config, "network_self_link", "")
  )

  # 3. Map of all HA VPN Gateways
  gateways_map = {
    for g in lookup(local.raw_config, "gateways", []) : g.name => g
  }

  # 4. Extract unique external peer gateways across all gateway definitions
  # Deduplicates by peer gateway name to prevent collisions when multiple gateways peer with the same device
  external_gateways_map = {
    for g in lookup(local.raw_config, "gateways", []) :
    g.peer_gateway.name => merge(g.peer_gateway, {
      project_id = local.project_id
    })
    if lookup(g, "peer_gateway", null) != null
  }

  # 5. Flatten all tunnels across all HA VPN gateways
  tunnels_flat = flatten([
    for g_key, g in local.gateways_map : [
      for t in lookup(g, "tunnels", []) : {
        gateway_name                    = g.name
        gateway_region                  = lookup(g, "region", local.default_region)
        router_name                     = lookup(g, "router_name", local.default_router_name)
        tunnel_name                     = "${g.name}-${t.name}"
        description                     = lookup(t, "description", "HA VPN Tunnel ${t.name} on ${g.name}")
        vpn_gateway_interface           = t.vpn_gateway_interface
        peer_gateway_name               = lookup(g.peer_gateway, "name", null)
        peer_external_gateway_id        = lookup(t, "peer_external_gateway_id", null)
        peer_external_gateway_interface = t.peer_external_gateway_interface
        shared_secret                   = t.shared_secret
        ike_version                     = lookup(t, "ike_version", 2)
        router_interface_name           = lookup(t, "router_interface_name", "${g.name}-${t.name}-if")
        router_peer_name                = lookup(t, "router_peer_name", "${g.name}-${t.name}-peer")
        router_interface_ip             = t.bgp_session.router_interface_ip
        peer_ip_address                 = t.bgp_session.peer_ip_address
        peer_asn                        = t.bgp_session.peer_asn
        advertised_route_priority       = lookup(t.bgp_session, "advertised_route_priority", 100)
        advertise_mode                  = lookup(t.bgp_session, "advertise_mode", null)
        advertised_groups               = lookup(t.bgp_session, "advertised_groups", null)
        advertised_ip_ranges            = lookup(t.bgp_session, "advertised_ip_ranges", [])
        bfd                             = lookup(t.bgp_session, "bfd", null)
        key                             = "${g.name}-${t.name}"
      }
    ]
  ])

  tunnels_map = { for t in local.tunnels_flat : t.key => t }
}
