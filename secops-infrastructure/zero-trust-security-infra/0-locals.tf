# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the YAML configuration and flattens Workload Identity Federation (WIF)
# pools, OIDC/AWS providers, dedicated Service Accounts, and Identity-Aware Proxy
# (IAP) TCP tunneling & Web HTTPS access rules for Terraform 'for_each' iteration.
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

  # Support optional wrapper root key "zero_trust_security" or "zero_trust"
  raw_root = try(local.raw_config.zero_trust_security, try(local.raw_config.zero_trust, local.raw_config))

  # Top-level global defaults
  default_project_id = try(local.raw_root.project_id, null)
  common_labels      = try(local.raw_root.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Workload Identity Federation (WIF) Pools & Providers
  # ----------------------------------------------------------------------------
  # Supports:
  # - workload_identity_pools: { pool-key: { ... } }
  # - workload_identity_pools: [ { pool_id: "...", ... } ]
  # - workload_identity_federation.pools
  raw_pools_input = try(
    local.raw_root.workload_identity_pools,
    try(
      local.raw_root.workload_identity_federation.pools,
      try(local.raw_root.wif.pools, {})
    )
  )

  # Normalize raw_pools_input into a uniform map
  pools_map = {
    for k, v in(
      can(keys(local.raw_pools_input)) ? local.raw_pools_input : {
        for idx, item in local.raw_pools_input : try(item.pool_id, try(item.name, "pool-${idx}")) => item
      }
      ) : k => {
      pool_id      = try(v.pool_id, k)
      project_id   = try(v.project_id, local.default_project_id)
      display_name = try(v.display_name, try(v.pool_id, k))
      description  = try(v.description, "Managed Workload Identity Pool for Keyless Authentication")
      disabled     = try(v.disabled, false)
      providers    = try(v.providers, {})
    }
  }

  # Flattened Providers Map across all pools
  # Each pool's providers can be a map or a list
  providers_list = flatten([
    for pool_key, pool in local.pools_map : [
      for pr_k, pr_v in(
        can(keys(pool.providers)) ? pool.providers : {
          for idx, item in pool.providers : try(item.provider_id, try(item.name, "provider-${idx}")) => item
        }
        ) : {
        composite_key       = "${pool.pool_id}/${try(pr_v.provider_id, pr_k)}"
        pool_key            = pool.pool_id
        provider_id         = try(pr_v.provider_id, pr_k)
        project_id          = pool.project_id
        display_name        = try(pr_v.display_name, try(pr_v.provider_id, pr_k))
        description         = try(pr_v.description, "Managed Workload Identity Provider")
        disabled            = try(pr_v.disabled, false)
        type                = lower(try(pr_v.type, try(pr_v.aws, null) != null ? "aws" : "oidc"))
        issuer_uri          = try(pr_v.issuer_uri, try(pr_v.oidc.issuer_uri, null))
        allowed_audiences   = try(pr_v.allowed_audiences, try(pr_v.oidc.allowed_audiences, []))
        aws_account_id      = try(pr_v.aws_account_id, try(pr_v.aws.account_id, null))
        attribute_mapping   = try(pr_v.attribute_mapping, {})
        attribute_condition = try(pr_v.attribute_condition, null)
      }
    ]
  ])

  providers_map = { for pr in local.providers_list : pr.composite_key => pr }

  # ----------------------------------------------------------------------------
  # 2. Dedicated WIF Service Accounts & Impersonation Bindings
  # ----------------------------------------------------------------------------
  # Supports service_accounts as map or list
  raw_sa_input = try(
    local.raw_root.service_accounts,
    try(
      local.raw_root.workload_identity_federation.service_accounts,
      try(local.raw_root.wif.service_accounts, {})
    )
  )

  service_accounts_map = {
    for k, v in(
      can(keys(local.raw_sa_input)) ? local.raw_sa_input : {
        for idx, item in local.raw_sa_input : try(item.account_id, try(item.name, "sa-${idx}")) => item
      }
      ) : k => {
      account_id   = try(v.account_id, k)
      project_id   = try(v.project_id, local.default_project_id)
      display_name = try(v.display_name, try(v.account_id, k))
      description  = try(v.description, "Service Account for Workload Identity Federation Impersonation")
      roles        = try(v.roles, [])
      bindings     = try(v.workload_identity_bindings, try(v.bindings, []))
    }
  }

  # Flattened GCP Project Roles granted to WIF Service Accounts
  sa_roles_list = flatten([
    for sa_key, sa in local.service_accounts_map : [
      for role in sa.roles : {
        composite_key = "${sa.account_id}/${role}"
        account_id    = sa.account_id
        project_id    = sa.project_id
        role          = role
      }
    ]
  ])

  sa_roles_map = { for r in local.sa_roles_list : r.composite_key => r }

  # Flattened Workload Identity User IAM bindings
  sa_wif_bindings_list = flatten([
    for sa_key, sa in local.service_accounts_map : [
      for idx, b in sa.bindings : {
        composite_key = "${sa.account_id}/${try(b.pool_key, b.pool)}/${idx}"
        account_id    = sa.account_id
        pool_key      = try(b.pool_key, b.pool)
        attribute = (
          try(b.attribute, null) != null ? b.attribute : (
            try(b.attribute_name, null) != null && try(b.attribute_value, null) != null ?
            "${b.attribute_name}/${b.attribute_value}" : "*"
          )
        )
      }
    ]
  ])

  sa_wif_bindings_map = { for b in local.sa_wif_bindings_list : b.composite_key => b }

  # ----------------------------------------------------------------------------
  # 3. Identity-Aware Proxy (IAP) - TCP Forwarding (Secure Tunneling for SSH/RDP)
  # ----------------------------------------------------------------------------
  raw_iap_tcp = try(
    local.raw_root.iap_tcp_tunneling,
    try(
      local.raw_root.identity_aware_proxy.tcp_tunneling,
      try(local.raw_root.iap.tcp_tunneling, {})
    )
  )

  enable_iap_firewall = try(local.raw_iap_tcp.enabled, try(local.raw_iap_tcp.enable_firewall, false))

  raw_fw = try(local.raw_iap_tcp.firewall_rule, {})

  iap_firewall_config = {
    name                    = try(local.raw_fw.name, try(local.raw_iap_tcp.firewall_name, "allow-iap-ingress-ssh-rdp"))
    project_id              = try(local.raw_fw.project_id, try(local.raw_iap_tcp.project_id, local.default_project_id))
    network                 = try(local.raw_fw.network, try(local.raw_iap_tcp.network, "default"))
    target_tags             = try(local.raw_fw.target_tags, try(local.raw_iap_tcp.target_tags, null))
    target_service_accounts = try(local.raw_fw.target_service_accounts, try(local.raw_iap_tcp.target_service_accounts, null))
    ports                   = try(local.raw_fw.ports, try(local.raw_iap_tcp.ports, ["22", "3389"]))
  }

  # Flattened IAP TCP Tunnel Accessor IAM members (roles/iap.tunnelResourceAccessor)
  iap_tcp_accessors_list = flatten([
    for idx, acc in try(local.raw_iap_tcp.accessors, []) : [
      for member in try(acc.members, try([acc.member], [])) : {
        composite_key = "${member}-${idx}"
        project_id    = try(acc.project_id, local.default_project_id)
        role          = try(acc.role, "roles/iap.tunnelResourceAccessor")
        member        = member
        condition     = try(acc.condition, null)
      }
    ]
  ])

  iap_tcp_accessors_map = { for a in local.iap_tcp_accessors_list : a.composite_key => a }

  # ----------------------------------------------------------------------------
  # 4. Identity-Aware Proxy (IAP) - Web Applications (HTTPS Load Balancers)
  # ----------------------------------------------------------------------------
  raw_iap_web = try(
    local.raw_root.iap_web_applications,
    try(
      local.raw_root.identity_aware_proxy.web_applications,
      try(local.raw_root.iap.web_applications, {})
    )
  )

  # Flattened Web Backend Service IAM accessors (roles/iap.httpsResourceAccessor)
  raw_backend_services_input = try(local.raw_iap_web.backend_services, {})
  backend_services_map = {
    for k, bs in(
      can(keys(local.raw_backend_services_input)) ? local.raw_backend_services_input : {
        for idx, item in local.raw_backend_services_input : try(item.name, "backend-${idx}") => item
      }
    ) : k => bs
  }

  iap_web_accessors_list = flatten([
    for bs_key, bs in local.backend_services_map : [
      for idx, acc in try(bs.accessors, []) : [
        for member in try(acc.members, try([acc.member], [])) : {
          composite_key       = "${try(bs.name, bs_key)}/${try(acc.role, "roles/iap.httpsResourceAccessor")}/${member}"
          web_backend_service = try(bs.name, bs_key)
          project_id          = try(bs.project_id, local.default_project_id)
          role                = try(acc.role, "roles/iap.httpsResourceAccessor")
          member              = member
          condition           = try(acc.condition, null)
        }
      ]
    ]
  ])

  iap_web_accessors_map = { for a in local.iap_web_accessors_list : a.composite_key => a }
}
