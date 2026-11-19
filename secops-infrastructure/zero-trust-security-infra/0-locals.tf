# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the YAML configuration and flattens Workload Identity Federation (WIF)
# pools, OIDC/AWS providers, dedicated Service Accounts, and Identity-Aware Proxy
# (IAP) TCP tunneling & Web HTTPS access rules for Terraform 'for_each' iteration.
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

  # Top-level global defaults
  default_project_id = try(local.raw_config.project_id, null)
  common_labels      = try(local.raw_config.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Workload Identity Federation (WIF) Pools & Providers
  # ----------------------------------------------------------------------------
  raw_wif = try(local.raw_config.workload_identity_federation, local.raw_config.wif, {})

  # Pools Map
  pools_map = {
    for p in try(local.raw_wif.pools, []) : try(p.pool_id, p.name) => {
      pool_id      = try(p.pool_id, p.name)
      project_id   = try(p.project_id, local.default_project_id)
      display_name = try(p.display_name, try(p.pool_id, p.name))
      description  = try(p.description, "Managed Workload Identity Pool for Keyless Authentication")
      disabled     = try(p.disabled, false)
      providers    = try(p.providers, [])
    }
  }

  # Flattened Providers Map across all pools
  providers_list = flatten([
    for pool_key, pool in local.pools_map : [
      for pr in pool.providers : {
        composite_key       = "${pool.pool_id}/${try(pr.provider_id, pr.name)}"
        pool_key            = pool.pool_id
        provider_id         = try(pr.provider_id, pr.name)
        project_id          = pool.project_id
        display_name        = try(pr.display_name, try(pr.provider_id, pr.name))
        description         = try(pr.description, "Managed Workload Identity Provider")
        disabled            = try(pr.disabled, false)
        type                = lower(try(pr.type, "oidc"))
        issuer_uri          = try(pr.issuer_uri, try(pr.oidc.issuer_uri, null))
        allowed_audiences   = try(pr.allowed_audiences, try(pr.oidc.allowed_audiences, []))
        aws_account_id      = try(pr.aws_account_id, try(pr.aws.account_id, null))
        attribute_mapping   = try(pr.attribute_mapping, {})
        attribute_condition = try(pr.attribute_condition, null)
      }
    ]
  ])

  providers_map = { for pr in local.providers_list : pr.composite_key => pr }

  # ----------------------------------------------------------------------------
  # 2. Dedicated WIF Service Accounts & Impersonation Bindings
  # ----------------------------------------------------------------------------
  raw_service_accounts = try(local.raw_wif.service_accounts, [])

  service_accounts_map = {
    for sa in local.raw_service_accounts : try(sa.account_id, sa.name) => {
      account_id   = try(sa.account_id, sa.name)
      project_id   = try(sa.project_id, local.default_project_id)
      display_name = try(sa.display_name, try(sa.account_id, sa.name))
      description  = try(sa.description, "Service Account for Workload Identity Federation Impersonation")
      roles        = try(sa.roles, [])
      bindings     = try(sa.bindings, [])
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
        composite_key = "${sa.account_id}/${b.pool}/${replace(b.attribute, "/", "-")}"
        account_id    = sa.account_id
        pool_key      = b.pool
        attribute     = b.attribute
      }
    ]
  ])

  sa_wif_bindings_map = { for b in local.sa_wif_bindings_list : b.composite_key => b }

  # ----------------------------------------------------------------------------
  # 3. Identity-Aware Proxy (IAP) - TCP Forwarding (Secure Tunneling for SSH/RDP)
  # ----------------------------------------------------------------------------
  raw_iap = try(local.raw_config.identity_aware_proxy, local.raw_config.iap, {})

  raw_iap_tcp = try(local.raw_iap.tcp_tunneling, {})

  enable_iap_firewall = try(local.raw_iap_tcp.enable_firewall, true)
  iap_firewall_config = {
    name                    = try(local.raw_iap_tcp.firewall_name, "allow-iap-ingress-ssh-rdp")
    project_id              = try(local.raw_iap_tcp.project_id, local.default_project_id)
    network                 = try(local.raw_iap_tcp.network, "default")
    target_tags             = try(local.raw_iap_tcp.target_tags, null)
    target_service_accounts = try(local.raw_iap_tcp.target_service_accounts, null)
    ports                   = try(local.raw_iap_tcp.ports, ["22", "3389"])
  }

  # Flattened IAP TCP Tunnel Accessor IAM members (roles/iap.tunnelResourceAccessor)
  iap_tcp_accessors_list = flatten([
    for idx, acc in try(local.raw_iap_tcp.accessors, []) : [
      for member in acc.members : {
        composite_key = "${member}-${idx}"
        project_id    = try(acc.project_id, local.default_project_id)
        role          = "roles/iap.tunnelResourceAccessor"
        member        = member
        condition     = try(acc.condition, null)
      }
    ]
  ])

  iap_tcp_accessors_map = { for a in local.iap_tcp_accessors_list : a.composite_key => a }

  # ----------------------------------------------------------------------------
  # 4. Identity-Aware Proxy (IAP) - Web Applications (HTTPS Load Balancers)
  # ----------------------------------------------------------------------------
  raw_iap_web = try(local.raw_iap.web_applications, {})

  # OAuth Brand (Created once per project if specified)
  create_iap_brand = try(local.raw_iap_web.brand, null) != null
  iap_brand_config = local.create_iap_brand ? {
    project_id        = try(local.raw_iap_web.brand.project_id, local.default_project_id)
    support_email     = local.raw_iap_web.brand.support_email
    application_title = local.raw_iap_web.brand.application_title
  } : null

  # OAuth Clients under the Brand
  iap_oauth_clients_map = {
    for c in try(local.raw_iap_web.oauth_clients, []) : c.name => {
      name         = c.name
      display_name = try(c.display_name, c.name)
    }
  }

  # Flattened Web Backend Service IAM accessors (roles/iap.httpsResourceAccessor)
  iap_web_accessors_list = flatten([
    for bs in try(local.raw_iap_web.backend_services, []) : [
      for acc in try(bs.accessors, []) : [
        for member in acc.members : {
          composite_key       = "${bs.name}/${try(acc.role, "roles/iap.httpsResourceAccessor")}/${member}"
          web_backend_service = bs.name
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
