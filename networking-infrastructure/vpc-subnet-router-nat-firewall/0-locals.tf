locals {
  raw_config     = yamldecode(file(var.config_file_path))
  project_id     = local.raw_config.project_id
  default_region = try(local.raw_config.region, "asia-south1")
  tags           = try(local.raw_config.tags, {})

  # ============================================================================
  # 1. VPC Configuration (Reference: terraform-google-modules/network/google)
  # ============================================================================
  raw_vpc  = try(local.raw_config.network.vpc, {})
  vpc_name = try(local.raw_vpc.network_name, local.raw_vpc.name, null)

  vpcs = local.vpc_name != null ? {
    (local.vpc_name) = {
      name                                      = local.vpc_name
      routing_mode                              = try(local.raw_vpc.routing_mode, "GLOBAL")
      description                               = try(local.raw_vpc.description, "Managed by Terraform")
      auto_create_subnetworks                   = try(local.raw_vpc.auto_create_subnetworks, false)
      delete_default_routes_on_create           = try(local.raw_vpc.delete_default_internet_gateway_routes, local.raw_vpc.delete_default_routes_on_create, false)
      mtu                                       = try(local.raw_vpc.mtu, null)
      enable_ula_internal_ipv6                  = try(local.raw_vpc.enable_ula_internal_ipv6, false)
      internal_ipv6_range                       = try(local.raw_vpc.internal_ipv6_range, null)
      network_firewall_policy_enforcement_order = try(local.raw_vpc.network_firewall_policy_enforcement_order, "AFTER_CLASSIC_FIREWALL")
    }
  } : {}

  # ============================================================================
  # 2. Subnetworks Configuration (Reference: terraform-google-modules/network/google)
  # ============================================================================
  subnets = {
    for subnet in try(local.raw_vpc.subnets, []) : try(subnet.subnet_name, subnet.name) => {
      vpc_name            = local.vpc_name
      subnet_name         = try(subnet.subnet_name, subnet.name)
      ip_cidr             = try(subnet.subnet_ip, subnet.ip_cidr)
      region              = try(subnet.subnet_region, subnet.region, local.default_region)
      private_access      = try(subnet.subnet_private_access, subnet.private_access, true)
      private_ipv6_access = try(subnet.subnet_private_ipv6_access, subnet.private_ipv6_access, null)
      description         = try(subnet.description, null)
      purpose             = try(subnet.purpose, null)
      role                = try(subnet.role, null)
      stack_type          = try(subnet.stack_type, null)
      ipv6_access_type    = try(subnet.ipv6_access_type, null)
      secondary_ranges = [
        for sec in try(subnet.secondary_ranges, []) : {
          range_name    = try(sec.range_name, sec.name)
          ip_cidr_range = try(sec.ip_cidr_range, sec.ip_cidr)
        }
      ]
      flow_logs_enabled         = try(subnet.subnet_flow_logs, subnet.flow_logs.enable, false)
      flow_logs_interval        = try(subnet.subnet_flow_logs_interval, subnet.flow_logs.aggregation_interval, "INTERVAL_5_SEC")
      flow_logs_sampling        = try(subnet.subnet_flow_logs_sampling, subnet.flow_logs.flow_sampling, 0.5)
      flow_logs_metadata        = try(subnet.subnet_flow_logs_metadata, subnet.flow_logs.metadata, "INCLUDE_ALL_METADATA")
      flow_logs_filter          = try(subnet.subnet_flow_logs_filter, subnet.flow_logs.filter_expr, "true")
      flow_logs_metadata_fields = try(subnet.subnet_flow_logs_metadata_fields, subnet.flow_logs.metadata_fields, null)
    }
  }

  # ============================================================================
  # 3. Cloud Routers & BGP (Reference: terraform-google-modules/cloud-router/google)
  # ============================================================================
  raw_routers = try(
    local.raw_config.network.router,
    local.raw_config.network.routers,
    local.raw_vpc.router,
    local.raw_vpc.routers,
    []
  )

  routers = {
    for router in local.raw_routers : router.name => {
      vpc_name                      = try(router.vpc_name, local.vpc_name)
      name                          = router.name
      region                        = try(router.region, local.default_region)
      description                   = try(router.description, "Managed by Terraform")
      encrypted_interconnect_router = try(router.encrypted_interconnect_router, false)
      bgp = can(router.bgp) && router.bgp != null ? {
        asn                = tonumber(router.bgp.asn)
        advertise_mode     = try(router.bgp.advertise_mode, "DEFAULT")
        advertised_groups  = try(router.bgp.advertise_mode, "DEFAULT") == "CUSTOM" ? try(router.bgp.advertised_groups, []) : null
        keepalive_interval = try(tonumber(router.bgp.keepalive_interval), 20)
        identifier_range   = try(router.bgp.identifier_range, null)
        advertised_ip_ranges = [
          for r in try(router.bgp.advertised_ip_ranges, []) : {
            range       = r.range
            description = try(r.description, null)
          }
        ]
      } : null
      interfaces = [
        for iface in try(router.interfaces, []) : {
          name                    = iface.name
          ip_range                = try(iface.ip_range, null)
          vpn_tunnel              = try(iface.vpn_tunnel, null)
          interconnect_attachment = try(iface.interconnect_attachment, null)
          redundant_interface     = try(iface.redundant_interface, null)
          subnetwork              = try(iface.subnetwork, null)
          private_ip_address      = try(iface.private_ip_address, null)
        }
      ]
      peers = [
        for peer in try(router.peers, []) : {
          name                      = peer.name
          interface                 = peer.interface
          peer_asn                  = tonumber(peer.peer_asn)
          ip_address                = try(peer.ip_address, null)
          peer_ip_address           = try(peer.peer_ip_address, null)
          advertised_route_priority = try(peer.advertised_route_priority, 100)
          advertise_mode            = try(peer.advertise_mode, "DEFAULT")
          advertised_groups         = try(peer.advertised_groups, null)
          advertised_ip_ranges = [
            for r in try(peer.advertised_ip_ranges, []) : {
              range       = r.range
              description = try(r.description, null)
            }
          ]
          enable = try(peer.enable, true)
          bfd    = try(peer.bfd, null)
        }
      ]
    }
  }

  router_interfaces = merge([
    for router_name, router in local.routers : {
      for iface in router.interfaces : "${router_name}/${iface.name}" => merge(iface, {
        router_name = router_name
        region      = router.region
      })
    }
  ]...)

  router_peers = merge([
    for router_name, router in local.routers : {
      for peer in router.peers : "${router_name}/${peer.name}" => merge(peer, {
        router_name = router_name
        region      = router.region
      })
    }
  ]...)

  # ============================================================================
  # 4. Cloud NAT Gateways (Reference: terraform-google-modules/cloud-nat/google)
  # ============================================================================
  raw_nats = try(
    local.raw_config.network.nat,
    local.raw_config.network.nats,
    local.raw_vpc.nat,
    local.raw_vpc.nats,
    []
  )

  nats = {
    for nat in local.raw_nats : nat.name => {
      vpc_name                            = try(nat.vpc_name, local.vpc_name)
      name                                = nat.name
      region                              = try(nat.region, local.default_region)
      router_name                         = nat.router_name
      nat_ip_allocate_option              = try(nat.nat_ip_allocate_option, length(try(nat.nat_ips, [])) > 0 ? "MANUAL_ONLY" : "AUTO_ONLY")
      nat_ips                             = try(nat.nat_ips, null)
      source_subnetwork_ip_ranges_to_nat  = try(nat.source_subnetwork_ip_ranges_to_nat, "ALL_SUBNETWORKS_ALL_IP_RANGES")
      min_ports_per_vm                    = try(nat.min_ports_per_vm, 64)
      max_ports_per_vm                    = try(nat.max_ports_per_vm, null)
      enable_dynamic_port_allocation      = try(nat.enable_dynamic_port_allocation, false)
      enable_endpoint_independent_mapping = try(nat.enable_endpoint_independent_mapping, false)
      icmp_idle_timeout_sec               = try(nat.icmp_idle_timeout_sec, 30)
      tcp_established_idle_timeout_sec    = try(nat.tcp_established_idle_timeout_sec, 1200)
      tcp_transitory_idle_timeout_sec     = try(nat.tcp_transitory_idle_timeout_sec, 30)
      tcp_time_wait_timeout_sec           = try(nat.tcp_time_wait_timeout_sec, 120)
      udp_idle_timeout_sec                = try(nat.udp_idle_timeout_sec, 30)
      enable_logging                      = try(nat.log_config.enable, nat.enable_logging, true)
      log_filter                          = try(nat.log_config.filter, nat.log_filter, "ERRORS_ONLY")
      subnetworks = [
        for sub in try(nat.subnetworks, []) : {
          name                     = sub.name
          source_ip_ranges_to_nat  = try(sub.source_ip_ranges_to_nat, ["ALL_IP_RANGES"])
          secondary_ip_range_names = try(sub.secondary_ip_range_names, null)
        }
      ]
    }
  }

  # ============================================================================
  # 5. Firewall Rules (Reference: terraform-google-modules/network/google)
  # ============================================================================
  raw_ingress_rules = [
    for rule in try(local.raw_vpc.firewall_rules.ingress, []) : merge(rule, { direction = "INGRESS" })
  ]
  raw_egress_rules = [
    for rule in try(local.raw_vpc.firewall_rules.egress, []) : merge(rule, { direction = "EGRESS" })
  ]
  all_raw_firewall_rules = concat(local.raw_ingress_rules, local.raw_egress_rules)

  firewall_rules = {
    for rule in local.all_raw_firewall_rules : rule.name => {
      vpc_name                = local.vpc_name
      rule_name               = rule.name
      direction               = rule.direction
      priority                = try(rule.priority, 1000)
      disabled                = try(rule.disabled, false)
      description             = try(rule.description, "Managed by Terraform")
      source_ranges           = rule.direction == "INGRESS" ? try(rule.source_ranges, null) : null
      destination_ranges      = rule.direction == "EGRESS" ? try(rule.destination_ranges, null) : null
      source_tags             = try(rule.source_tags, null)
      target_tags             = try(rule.target_tags, null)
      source_service_accounts = try(rule.source_service_accounts, null)
      target_service_accounts = try(rule.target_service_accounts, null)
      enable_logging          = try(rule.log_config.enable, rule.enable_logging, false)
      log_metadata            = try(rule.log_config.metadata, rule.log_metadata, "INCLUDE_ALL_METADATA")

      allows = try(
        rule.allow,
        rule.allows,
        try(rule.action, "allow") == "allow" && (can(rule.ports) || can(rule.protocol)) ? [
          {
            protocol = try(rule.protocol, "tcp")
            ports    = try(rule.ports, null)
          }
        ] : []
      )

      denies = try(
        rule.deny,
        rule.denies,
        try(rule.action, "allow") == "deny" && (can(rule.ports) || can(rule.protocol)) ? [
          {
            protocol = try(rule.protocol, "tcp")
            ports    = try(rule.ports, null)
          }
        ] : []
      )
    }
  }

  # ============================================================================
  # 6. Private Service Access (Reference: terraform-google-modules/network/google)
  # ============================================================================
  raw_psa = try(
    local.raw_config.network.private_service_access,
    local.raw_vpc.private_service_access,
    null
  )

  psa_enabled = local.raw_psa != null ? try(local.raw_psa.enabled, true) : false

  raw_psa_ranges = local.psa_enabled ? try(
    local.raw_psa.ranges,
    [
      {
        name          = try(local.raw_psa.name, "${local.vpc_name}-psa-range")
        address       = try(local.raw_psa.address, null)
        prefix_length = try(local.raw_psa.prefix_length, 16)
        description   = try(local.raw_psa.description, "Private Service Access range managed by Terraform")
      }
    ]
  ) : []

  psa_ranges = {
    for r in local.raw_psa_ranges : r.name => {
      vpc_name      = local.vpc_name
      name          = r.name
      address       = try(r.address, null)
      prefix_length = try(r.prefix_length, 16)
      description   = try(r.description, "Private Service Access range managed by Terraform")
    }
  }

  psa_connection = local.psa_enabled && length(local.psa_ranges) > 0 ? {
    (local.vpc_name) = {
      vpc_name             = local.vpc_name
      service              = try(local.raw_psa.service, "servicenetworking.googleapis.com")
      deletion_policy      = try(local.raw_psa.deletion_policy, null)
      export_custom_routes = try(local.raw_psa.export_custom_routes, false)
      import_custom_routes = try(local.raw_psa.import_custom_routes, false)
    }
  } : {}
}
