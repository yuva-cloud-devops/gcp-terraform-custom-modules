# ==============================================================================
# METADATA & TAGS OUTPUTS
# ==============================================================================

output "project_id" {
  description = "The GCP project ID where networking resources are provisioned."
  value       = local.project_id
}

output "tags" {
  description = "Common metadata tags/labels defined in the YAML configuration."
  value       = local.tags
}

# ==============================================================================
# VPC NETWORKS OUTPUTS
# ==============================================================================

output "vpcs" {
  description = "Detailed map of all created VPC networks."
  value = {
    for k, v in google_compute_network.vpcs : k => {
      id                              = v.id
      name                            = v.name
      self_link                       = v.self_link
      gateway_ipv4                    = v.gateway_ipv4
      routing_mode                    = v.routing_mode
      mtu                             = v.mtu
      delete_default_routes_on_create = v.delete_default_routes_on_create
    }
  }
}

output "vpc_ids" {
  description = "Lookup map of VPC name to VPC ID."
  value       = { for k, v in google_compute_network.vpcs : k => v.id }
}

output "vpc_self_links" {
  description = "Lookup map of VPC name to VPC self link."
  value       = { for k, v in google_compute_network.vpcs : k => v.self_link }
}

# ==============================================================================
# SUBNETWORKS OUTPUTS
# ==============================================================================

output "subnets" {
  description = "Detailed map of all created subnetworks."
  value = {
    for k, v in google_compute_subnetwork.subnets : k => {
      id                       = v.id
      name                     = v.name
      vpc_name                 = local.subnets[k].vpc_name
      region                   = v.region
      network                  = v.network
      ip_cidr_range            = v.ip_cidr_range
      gateway_address          = v.gateway_address
      self_link                = v.self_link
      private_ip_google_access = v.private_ip_google_access
      purpose                  = v.purpose
      role                     = v.role
      secondary_ip_ranges      = v.secondary_ip_range
      secondary_ranges_map = {
        for sec in v.secondary_ip_range : sec.range_name => sec.ip_cidr_range
      }
    }
  }
}

output "subnet_ids" {
  description = "Lookup map of subnet name to subnet ID."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Lookup map of subnet name to subnet self link."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "subnet_cidrs" {
  description = "Lookup map of subnet name to primary IP CIDR block."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range }
}

# ==============================================================================
# CLOUD ROUTER & BGP OUTPUTS
# ==============================================================================

output "routers" {
  description = "Detailed map of all created Cloud Routers including BGP configuration."
  value = {
    for k, v in google_compute_router.routers : k => {
      id                            = v.id
      name                          = v.name
      vpc_name                      = local.routers[k].vpc_name
      region                        = v.region
      network                       = v.network
      encrypted_interconnect_router = v.encrypted_interconnect_router
      bgp                           = v.bgp
      self_link                     = v.self_link
    }
  }
}

output "router_ids" {
  description = "Lookup map of Cloud Router name to Router ID."
  value       = { for k, v in google_compute_router.routers : k => v.id }
}

output "router_self_links" {
  description = "Lookup map of Cloud Router name to Router self link."
  value       = { for k, v in google_compute_router.routers : k => v.self_link }
}

output "router_bgp_peers" {
  description = "Detailed map of all created Cloud Router BGP peers."
  value = {
    for k, v in google_compute_router_peer.peers : k => {
      id              = v.id
      name            = v.name
      router          = v.router
      region          = v.region
      interface       = v.interface
      peer_asn        = v.peer_asn
      ip_address      = v.ip_address
      peer_ip_address = v.peer_ip_address
      management_type = v.management_type
    }
  }
}

# ==============================================================================
# CLOUD NAT GATEWAYS OUTPUTS
# ==============================================================================

output "nat_gateways" {
  description = "Detailed map of all created Cloud NAT gateways."
  value = {
    for k, v in google_compute_router_nat.nats : k => {
      id                                  = v.id
      name                                = v.name
      vpc_name                            = local.nats[k].vpc_name
      region                              = v.region
      router                              = v.router
      nat_ip_allocate_option              = v.nat_ip_allocate_option
      source_subnetwork_ip_ranges_to_nat  = v.source_subnetwork_ip_ranges_to_nat
      nat_ips                             = v.nat_ips
      min_ports_per_vm                    = v.min_ports_per_vm
      max_ports_per_vm                    = v.max_ports_per_vm
      enable_dynamic_port_allocation      = v.enable_dynamic_port_allocation
      enable_endpoint_independent_mapping = v.enable_endpoint_independent_mapping
      log_config                          = v.log_config
    }
  }
}

output "nat_ids" {
  description = "Lookup map of Cloud NAT name to Cloud NAT ID."
  value       = { for k, v in google_compute_router_nat.nats : k => v.id }
}

# ==============================================================================
# FIREWALL RULES OUTPUTS
# ==============================================================================

output "firewall_rules" {
  description = "Detailed map of all created Firewall Rules."
  value = {
    for k, v in google_compute_firewall.rules : k => {
      id                      = v.id
      name                    = v.name
      vpc_name                = local.firewall_rules[k].vpc_name
      network                 = v.network
      direction               = v.direction
      priority                = v.priority
      disabled                = v.disabled
      description             = v.description
      source_ranges           = v.source_ranges
      destination_ranges      = v.destination_ranges
      source_tags             = v.source_tags
      target_tags             = v.target_tags
      source_service_accounts = v.source_service_accounts
      target_service_accounts = v.target_service_accounts
      allow                   = v.allow
      deny                    = v.deny
      log_config              = v.log_config
      self_link               = v.self_link
    }
  }
}

output "firewall_rule_ids" {
  description = "Lookup map of firewall rule name to Firewall ID."
  value       = { for k, v in google_compute_firewall.rules : k => v.id }
}

output "firewall_rule_self_links" {
  description = "Lookup map of firewall rule name to Firewall self link."
  value       = { for k, v in google_compute_firewall.rules : k => v.self_link }
}

# ==============================================================================
# PRIVATE SERVICE ACCESS (PSA) OUTPUTS
# ==============================================================================

output "private_service_access_ranges" {
  description = "Map of allocated internal IP ranges for Private Service Access (Cloud SQL, Memorystore, etc.)."
  value = {
    for k, v in google_compute_global_address.psa_ranges : k => {
      id            = v.id
      name          = v.name
      address       = v.address
      prefix_length = v.prefix_length
      cidr          = "${v.address}/${v.prefix_length}"
      purpose       = v.purpose
      address_type  = v.address_type
      network       = v.network
      self_link     = v.self_link
    }
  }
}

output "private_service_access_connections" {
  description = "Details of the Private Service Access peering connections."
  value = {
    for k, v in google_service_networking_connection.psa_connection : k => {
      id                      = v.id
      network                 = v.network
      service                 = v.service
      peering                 = v.peering
      reserved_peering_ranges = v.reserved_peering_ranges
    }
  }
}
