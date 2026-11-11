locals {
  raw_config     = yamldecode(file(var.config_file_path))
  project_id     = local.raw_config.project_id
  default_region = try(local.raw_config.region, "asia-south1")
  tags           = try(local.raw_config.tags, {})

  # ============================================================================
  # 1. VPC Configuration (Supports single `network.vpc` or multi-VPC `network.vpcs`)
  #    Reference: terraform-google-modules/network/google
  # ============================================================================
  raw_vpcs = try(
    local.raw_config.network.vpcs,
    local.raw_config.vpcs,
    can(local.raw_config.network.vpc[0]) ? local.raw_config.network.vpc : [local.raw_config.network.vpc],
    []
  )

  default_vpc_name = try(local.raw_vpcs[0].network_name, local.raw_vpcs[0].name, null)

  vpcs = {
    for vpc in local.raw_vpcs : try(vpc.network_name, vpc.name) => {
      name                                      = try(vpc.network_name, vpc.name)
      routing_mode                              = try(vpc.routing_mode, "GLOBAL")
      description                               = try(vpc.description, "Managed by Terraform")
      auto_create_subnetworks                   = try(vpc.auto_create_subnetworks, false)
      delete_default_routes_on_create           = try(vpc.delete_default_internet_gateway_routes, vpc.delete_default_routes_on_create, false)
      mtu                                       = try(vpc.mtu, null)
      enable_ula_internal_ipv6                  = try(vpc.enable_ula_internal_ipv6, false)
      internal_ipv6_range                       = try(vpc.internal_ipv6_range, null)
      network_firewall_policy_enforcement_order = try(vpc.network_firewall_policy_enforcement_order, "AFTER_CLASSIC_FIREWALL")
    }
  }

  # ============================================================================
  # 2. Subnetworks Configuration (Across all VPCs)
  #    Reference: terraform-google-modules/network/google
  # ============================================================================
  subnets = merge([
    for vpc in local.raw_vpcs : {
      for subnet in try(vpc.subnets, []) : try(subnet.subnet_name, subnet.name) => {
        vpc_name            = try(vpc.network_name, vpc.name)
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
  ]...)

  # ============================================================================
  # 3. Cloud Routers & BGP (Supports per-VPC `router` or top-level `network.router`)
  #    Reference: terraform-google-modules/cloud-router/google
  # ============================================================================
  vpc_level_routers = flatten([
    for vpc in local.raw_vpcs : [
      for r in try(vpc.router, vpc.routers, []) : merge(r, {
        vpc_name = try(r.vpc_name, vpc.network_name, vpc.name)
      })
    ]
  ])

  network_level_routers = [
    for r in try(local.raw_config.network.router, local.raw_config.network.routers, []) : merge(r, {
      vpc_name = try(r.vpc_name, local.default_vpc_name)
    })
  ]

  all_raw_routers = concat(local.vpc_level_routers, local.network_level_routers)

  routers = {
    for router in local.all_raw_routers : router.name => {
      vpc_name                      = router.vpc_name
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
  # 4. Cloud NAT Gateways (Supports per-VPC `nat` or top-level `network.nat`)
  #    Reference: terraform-google-modules/cloud-nat/google
  # ============================================================================
  vpc_level_nats = flatten([
    for vpc in local.raw_vpcs : [
      for n in try(vpc.nat, vpc.nats, []) : merge(n, {
        vpc_name = try(n.vpc_name, vpc.network_name, vpc.name)
      })
    ]
  ])

  network_level_nats = [
    for n in try(local.raw_config.network.nat, local.raw_config.network.nats, []) : merge(n, {
      vpc_name = try(n.vpc_name, local.routers[n.router_name].vpc_name, local.default_vpc_name)
    })
  ]

  all_raw_nats = concat(local.vpc_level_nats, local.network_level_nats)

  nats = {
    for nat in local.all_raw_nats : nat.name => {
      vpc_name                            = nat.vpc_name
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
  # 5. Firewall Rules (Across all VPCs)
  #    Reference: terraform-google-modules/network/google
  # ============================================================================
  all_raw_firewall_rules = flatten([
    for vpc in local.raw_vpcs : concat(
      [
        for rule in try(vpc.firewall_rules.ingress, []) : merge(rule, {
          vpc_name  = try(vpc.network_name, vpc.name)
          direction = "INGRESS"
        })
      ],
      [
        for rule in try(vpc.firewall_rules.egress, []) : merge(rule, {
          vpc_name  = try(vpc.network_name, vpc.name)
          direction = "EGRESS"
        })
      ]
    )
  ])

  firewall_rules = {
    for rule in local.all_raw_firewall_rules : rule.name => {
      vpc_name                = rule.vpc_name
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
  # 6. Private Service Access (Supports per-VPC `private_service_access`)
  #    Reference: terraform-google-modules/network/google
  # ============================================================================
  vpc_psa_configs = {
    for vpc in local.raw_vpcs : try(vpc.network_name, vpc.name) => try(vpc.private_service_access, null)
    if try(vpc.private_service_access, null) != null && try(vpc.private_service_access.enabled, true)
  }

  psa_ranges = merge([
    for vpc_name, psa in local.vpc_psa_configs : {
      for r in try(
        psa.ranges,
        [
          {
            name          = try(psa.name, "${vpc_name}-psa-range")
            address       = try(psa.address, null)
            prefix_length = try(psa.prefix_length, 16)
            description   = try(psa.description, "Private Service Access range for ${vpc_name}")
          }
        ]
        ) : r.name => {
        vpc_name      = vpc_name
        name          = r.name
        address       = try(r.address, null)
        prefix_length = try(r.prefix_length, 16)
        description   = try(r.description, "Private Service Access range for ${vpc_name}")
      }
    }
  ]...)

  psa_connection = {
    for vpc_name, psa in local.vpc_psa_configs : vpc_name => {
      vpc_name             = vpc_name
      service              = try(psa.service, "servicenetworking.googleapis.com")
      deletion_policy      = try(psa.deletion_policy, null)
      export_custom_routes = try(psa.export_custom_routes, false)
      import_custom_routes = try(psa.import_custom_routes, false)
    }
  }
}
