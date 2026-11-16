# ==============================================================================
# HA CLOUD VPN EXAMPLE: OUTPUTS
# ==============================================================================

output "vpn_vpc_id" {
  description = "The ID of the provisioned VPN VPC network."
  value       = google_compute_network.vpn_vpc.id
}

output "vpn_vpc_self_link" {
  description = "The self-link of the provisioned VPN VPC network."
  value       = google_compute_network.vpn_vpc.self_link
}

output "cloud_router_name" {
  description = "Name of the provisioned Cloud Router managing BGP."
  value       = google_compute_router.vpn_router.name
}

output "gateway_public_ips" {
  description = "Public IP addresses for GCP HA VPN Gateway interfaces (configure on remote edge firewall)."
  value       = module.ha_vpn.gateway_public_ips
}

output "gateways" {
  description = "Detailed map of provisioned HA VPN Gateways."
  value       = module.ha_vpn.gateways
}

output "external_gateways" {
  description = "Registered external on-premises peer gateways."
  value       = module.ha_vpn.external_gateways
}

output "tunnels" {
  description = "Provisioned IPsec VPN tunnels."
  value       = module.ha_vpn.tunnels
}

output "tunnel_ids" {
  description = "Resource IDs of the provisioned VPN tunnels."
  value       = module.ha_vpn.tunnel_ids
}

output "router_interfaces" {
  description = "Configured Cloud Router BGP interfaces."
  value       = module.ha_vpn.router_interfaces
}

output "router_peers" {
  description = "Configured Cloud Router eBGP peering sessions."
  value       = module.ha_vpn.router_peers
}

output "total_tunnels_count" {
  description = "Total number of active VPN tunnels provisioned."
  value       = module.ha_vpn.total_tunnels_count
}
