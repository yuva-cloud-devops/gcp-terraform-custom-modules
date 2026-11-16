# ==============================================================================
# HA CLOUD VPN MODULE: OUTPUTS
# ==============================================================================
# Exports gateways, external gateways, tunnels, router interfaces, BGP peers,
# and public IP mappings required for remote firewall configuration.
# ==============================================================================

output "gateways" {
  description = "Map of created Google Cloud HA VPN Gateways."
  value = {
    for k, v in google_compute_ha_vpn_gateway.gateway : k => {
      id             = v.id
      name           = v.name
      region         = v.region
      self_link      = v.self_link
      vpn_interfaces = v.vpn_interfaces
    }
  }
}

output "gateway_public_ips" {
  description = "GCP HA VPN Gateway public IP addresses to configure on the remote on-premises/peer firewall."
  value = {
    for k, v in google_compute_ha_vpn_gateway.gateway : k => {
      interface_0_ip = v.vpn_interfaces[0].ip_address
      interface_1_ip = v.vpn_interfaces[1].ip_address
    }
  }
}

output "external_gateways" {
  description = "Map of external VPN peer gateways registered with Google Cloud."
  value = {
    for k, v in google_compute_external_vpn_gateway.external_gateway : k => {
      id              = v.id
      name            = v.name
      redundancy_type = v.redundancy_type
      interfaces      = v.interface
    }
  }
}

output "tunnels" {
  description = "Map of all provisioned IPsec VPN tunnels."
  value = {
    for k, v in google_compute_vpn_tunnel.tunnel : k => {
      id                              = v.id
      name                            = v.name
      region                          = v.region
      vpn_gateway                     = v.vpn_gateway
      vpn_gateway_interface           = v.vpn_gateway_interface
      peer_external_gateway           = v.peer_external_gateway
      peer_external_gateway_interface = v.peer_external_gateway_interface
      detailed_status                 = v.detailed_status
    }
  }
}

output "tunnel_ids" {
  description = "Lookup map of VPN tunnel names to their resource IDs."
  value       = { for k, v in google_compute_vpn_tunnel.tunnel : k => v.id }
}

output "router_interfaces" {
  description = "Map of Cloud Router BGP interfaces configured for the VPN tunnels."
  value = {
    for k, v in google_compute_router_interface.interface : k => {
      name       = v.name
      router     = v.router
      region     = v.region
      ip_range   = v.ip_range
      vpn_tunnel = v.vpn_tunnel
    }
  }
}

output "router_peers" {
  description = "Map of Cloud Router BGP peers configured for eBGP sessions."
  value = {
    for k, v in google_compute_router_peer.peer : k => {
      name                      = v.name
      router                    = v.router
      region                    = v.region
      interface                 = v.interface
      peer_ip_address           = v.peer_ip_address
      peer_asn                  = v.peer_asn
      advertised_route_priority = v.advertised_route_priority
    }
  }
}

output "total_gateways_count" {
  description = "Total number of HA VPN Gateways provisioned."
  value       = length(google_compute_ha_vpn_gateway.gateway)
}

output "total_tunnels_count" {
  description = "Total number of IPsec VPN tunnels provisioned."
  value       = length(google_compute_vpn_tunnel.tunnel)
}

output "total_bgp_peers_count" {
  description = "Total number of BGP peer sessions configured."
  value       = length(google_compute_router_peer.peer)
}
