# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the YAML configuration and flattens Cloud Armor WAF security policies,
# Cloud IDS endpoints, and VPC Service Controls (VPC SC) perimeters & access levels
# for Terraform dynamic resource iteration.
# Supports both map-based (idiomatic key-value) and list-based YAML structures.
# ==============================================================================

locals {
  # ----------------------------------------------------------------------------
  # Raw Configuration Input (File Path or Raw Content)
  # ----------------------------------------------------------------------------
  raw_config = yamldecode(
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? file(var.config_file_path) : "{}"
    )
  )

  # Support optional wrapper root key "edge_security" or "edge_security_infra"
  raw_root = try(local.raw_config.edge_security, try(local.raw_config.edge_security_infra, local.raw_config))

  # Top-level global defaults
  default_project_id = try(local.raw_root.project_id, null)
  common_labels      = try(local.raw_root.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Cloud Armor Security Policies & WAF Rules
  # ----------------------------------------------------------------------------
  raw_armor_input = try(
    local.raw_root.cloud_armor_policies,
    try(
      local.raw_root.cloud_armor,
      try(local.raw_root.waf_policies, {})
    )
  )

  # Normalize policies into a uniform map (supports both map and list in YAML)
  armor_policies_map = {
    for k, v in local.raw_armor_input : try(v.name, try(v.policy_id, tostring(k))) => {
      name                = try(v.name, try(v.policy_id, tostring(k)))
      project_id          = try(v.project_id, local.default_project_id)
      description         = try(v.description, "Managed Cloud Armor Security Policy")
      type                = try(v.type, "CLOUD_ARMOR")
      default_rule_action = try(v.default_rule_action, "deny(403)")
      adaptive_protection = try(v.adaptive_protection, false)
      json_parsing        = try(v.advanced_options.json_parsing, "STANDARD")
      log_level           = try(v.advanced_options.log_level, "NORMAL")
      rules               = try(v.rules, {})
    }
  }

  # Normalize rules inside each Cloud Armor policy
  # Generates full rule object with match type, IP ranges, CEL expressions, and rate limits
  armor_rules_list = flatten([
    for policy_key, policy in local.armor_policies_map : [
      for r_k, r_v in policy.rules : {
        composite_key = "${policy.name}/${try(r_v.priority, r_k)}"
        policy_name   = policy.name
        project_id    = policy.project_id
        priority      = try(r_v.priority, tonumber(r_k))
        action        = try(r_v.action, "deny(403)")
        preview       = try(r_v.preview, false)
        description   = try(r_v.description, "Cloud Armor rule")

        # Match logic: IP ranges vs Expression vs OWASP Preconfigured Ruleset
        match_type = (
          try(r_v.owasp_ruleset, null) != null ? "owasp" : (
            try(r_v.ip_ranges, null) != null ? "ip" : "expr"
          )
        )
        src_ip_ranges = try(r_v.ip_ranges, [])
        expression = (
          try(r_v.owasp_ruleset, null) != null ?
          "evaluatePreconfiguredExpr('${r_v.owasp_ruleset}')" :
          try(r_v.expression, try(r_v.expr, null))
        )

        # Rate Limiting & Throttling Options
        rate_limit_options = try(r_v.rate_limit_options, null)
      }
    ]
  ])

  armor_rules_map = { for r in local.armor_rules_list : r.composite_key => r }

  # ----------------------------------------------------------------------------
  # 2. Cloud IDS (Intrusion Detection System) Endpoints
  # ----------------------------------------------------------------------------
  raw_ids_input = try(
    local.raw_root.cloud_ids_endpoints,
    try(
      local.raw_root.cloud_ids,
      try(local.raw_root.ids_endpoints, {})
    )
  )

  cloud_ids_map = {
    for k, v in local.raw_ids_input : try(v.name, try(v.endpoint_id, tostring(k))) => {
      name        = try(v.name, try(v.endpoint_id, tostring(k)))
      project_id  = try(v.project_id, local.default_project_id)
      location    = try(v.location, try(v.zone, "asia-south1-a"))
      network     = try(v.network, "default")
      severity    = upper(try(v.severity, "MEDIUM")) # INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL
      description = try(v.description, "Managed Cloud IDS threat detection endpoint")
    }
  }

  # ----------------------------------------------------------------------------
  # 3. VPC Service Controls (VPC SC) & Access Context Manager (ACM)
  # ----------------------------------------------------------------------------
  raw_vpc_sc = try(
    local.raw_root.vpc_service_controls,
    try(local.raw_root.vpc_sc, {})
  )

  access_policy_id = try(local.raw_vpc_sc.access_policy_id, null)

  # Access Levels (IP subnets, members, devices)
  raw_access_levels_input = try(local.raw_vpc_sc.access_levels, {})
  access_levels_map = {
    for k, v in local.raw_access_levels_input : try(v.name, tostring(k)) => {
      name                   = try(v.name, tostring(k))
      title                  = try(v.title, try(v.name, tostring(k)))
      description            = try(v.description, "Managed Access Level")
      combining_function     = try(v.combining_function, "AND")
      ip_subnetworks         = try(v.ip_subnetworks, [])
      members                = try(v.members, [])
      regions                = try(v.regions, [])
      required_access_levels = try(v.required_access_levels, [])
      device_policy          = try(v.device_policy, null)
    }
  }

  # Service Perimeters (Protected resources, restricted services, ingress/egress)
  raw_perimeters_input = try(local.raw_vpc_sc.service_perimeters, {})
  perimeters_map = {
    for k, v in local.raw_perimeters_input : try(v.name, tostring(k)) => {
      name                      = try(v.name, tostring(k))
      title                     = try(v.title, try(v.name, tostring(k)))
      description               = try(v.description, "Managed VPC Service Controls Perimeter")
      perimeter_type            = try(v.perimeter_type, "PERIMETER_TYPE_REGULAR")
      use_explicit_dry_run_spec = try(v.use_explicit_dry_run_spec, false)
      restricted_services       = try(v.restricted_services, [])
      resources                 = try(v.resources, [])
      access_levels             = try(v.access_levels, [])
      ingress_policies          = try(v.ingress_policies, [])
      egress_policies           = try(v.egress_policies, [])
    }
  }
}
