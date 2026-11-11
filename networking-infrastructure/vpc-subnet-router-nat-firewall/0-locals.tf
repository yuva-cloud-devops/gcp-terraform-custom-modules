locals {
  raw_config = yamldecode(file(var.config_file_path))
  project_id = local.raw_config.project_id

  # 1. Map of all VPCs
  vpcs = {
    for vpc in try(local.raw_config.vpcs, []) : vpc.name => {
      name                            = vpc.name
      routing_mode                    = try(vpc.routing_mode, "GLOBAL")
      description                     = try(vpc.description, "Managed by Terraform")
      delete_default_routes_on_create = try(vpc.delete_default_routes_on_create, false)
    }
  }

  # 2. Flatten all Subnets across all VPCs: Key = "<vpc_name>/<subnet_name>"
  subnets = merge([
    for vpc in try(local.raw_config.vpcs, []) : {
      for subnet in try(vpc.subnets, []) : "${vpc.name}/${subnet.name}" => {
        vpc_name         = vpc.name
        subnet_name      = subnet.name
        ip_cidr          = subnet.ip_cidr
        region           = subnet.region
        private_access   = try(subnet.private_access, true)
        description      = try(subnet.description, null)
        secondary_ranges = try(subnet.secondary_ranges, [])
      }
    }
  ]...)

  # 3. Flatten all Routers & NATs across all VPCs: Key = "<vpc_name>/<nat_name>"
  nats = merge([
    for vpc in try(local.raw_config.vpcs, []) : {
      for nat in try(vpc.nats, []) : "${vpc.name}/${nat.name}" => {
        vpc_name    = vpc.name
        nat_name    = nat.name
        region      = nat.region
        router_name = try(nat.router_name, "${vpc.name}-${nat.region}-router")
        log_filter  = try(nat.log_filter, "ERRORS_ONLY")
      }
    }
  ]...)

  # 4. Flatten all Firewall Rules across all VPCs: Key = "<vpc_name>/<rule_name>"
  firewall_rules = merge([
    for vpc in try(local.raw_config.vpcs, []) : {
      for rule in try(vpc.firewall_rules, []) : "${vpc.name}/${rule.name}" => {
        vpc_name           = vpc.name
        rule_name          = rule.name
        direction          = try(rule.direction, "INGRESS")
        priority           = try(rule.priority, 1000)
        description        = try(rule.description, "Managed via YAML")
        source_ranges      = try(rule.source_ranges, null)
        destination_ranges = try(rule.destination_ranges, null)
        source_tags        = try(rule.source_tags, null)
        target_tags        = try(rule.target_tags, null)
        allows             = try(rule.allows, [])
        denies             = try(rule.denies, [])
      }
    }
  ]...)
}
