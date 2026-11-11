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
  description = "Detailed map of all created subnetworks keyed by '<vpc_name>/<subnet_name>'."
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
      secondary_ip_ranges      = v.secondary_ip_range
      secondary_ranges_map = {
        for sec in v.secondary_ip_range : sec.range_name => sec.ip_cidr_range
      }
    }
  }
}

output "subnet_ids" {
  description = "Lookup map of subnet key ('<vpc_name>/<subnet_name>') to subnet ID."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Lookup map of subnet key ('<vpc_name>/<subnet_name>') to subnet self link."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "subnet_cidrs" {
  description = "Lookup map of subnet key ('<vpc_name>/<subnet_name>') to primary IP CIDR block."
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range }
}

# ==============================================================================
# CLOUD ROUTER OUTPUTS
# ==============================================================================

output "routers" {
  description = "Detailed map of all created Cloud Routers keyed by '<vpc_name>/<nat_name>'."
  value = {
    for k, v in google_compute_router.routers : k => {
      id        = v.id
      name      = v.name
      vpc_name  = local.nats[k].vpc_name
      region    = v.region
      network   = v.network
      self_link = v.self_link
    }
  }
}

output "router_ids" {
  description = "Lookup map of Cloud Router key ('<vpc_name>/<nat_name>') to Router ID."
  value       = { for k, v in google_compute_router.routers : k => v.id }
}

output "router_self_links" {
  description = "Lookup map of Cloud Router key ('<vpc_name>/<nat_name>') to Router self link."
  value       = { for k, v in google_compute_router.routers : k => v.self_link }
}

# ==============================================================================
# CLOUD NAT GATEWAYS OUTPUTS
# ==============================================================================

output "nat_gateways" {
  description = "Detailed map of all created Cloud NAT gateways keyed by '<vpc_name>/<nat_name>'."
  value = {
    for k, v in google_compute_router_nat.nats : k => {
      id                                 = v.id
      name                               = v.name
      vpc_name                           = local.nats[k].vpc_name
      region                             = v.region
      router                             = v.router
      nat_ip_allocate_option             = v.nat_ip_allocate_option
      source_subnetwork_ip_ranges_to_nat = v.source_subnetwork_ip_ranges_to_nat
      nat_ips                            = v.nat_ips
    }
  }
}

output "nat_ids" {
  description = "Lookup map of Cloud NAT key ('<vpc_name>/<nat_name>') to Cloud NAT ID."
  value       = { for k, v in google_compute_router_nat.nats : k => v.id }
}

# ==============================================================================
# FIREWALL RULES OUTPUTS
# ==============================================================================

output "firewall_rules" {
  description = "Detailed map of all created Firewall Rules keyed by '<vpc_name>/<rule_name>'."
  value = {
    for k, v in google_compute_firewall.rules : k => {
      id                 = v.id
      name               = v.name
      vpc_name           = local.firewall_rules[k].vpc_name
      network            = v.network
      direction          = v.direction
      priority           = v.priority
      description        = v.description
      source_ranges      = v.source_ranges
      destination_ranges = v.destination_ranges
      source_tags        = v.source_tags
      target_tags        = v.target_tags
      allow              = v.allow
      deny               = v.deny
      self_link          = v.self_link
    }
  }
}

output "firewall_rule_ids" {
  description = "Lookup map of firewall rule key ('<vpc_name>/<rule_name>') to Firewall ID."
  value       = { for k, v in google_compute_firewall.rules : k => v.id }
}

output "firewall_rule_self_links" {
  description = "Lookup map of firewall rule key ('<vpc_name>/<rule_name>') to Firewall self link."
  value       = { for k, v in google_compute_firewall.rules : k => v.self_link }
}
