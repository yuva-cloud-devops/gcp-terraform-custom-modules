# ==============================================================================
# 2. Certificate Manager (TLS Lifecycle, DNS Auth, Certificate Maps)
# ==============================================================================
# Provisions Google-managed public / private TLS certificates, DNS authorizations,
# Certificate Issuance Configs connected to CAS, and Certificate Maps for HTTPS LBs.
# ==============================================================================

# ------------------------------------------------------------------------------
# DNS Authorizations for Managed Wildcard and Domain Verification
# ------------------------------------------------------------------------------
resource "google_certificate_manager_dns_authorization" "dns_auths" {
  for_each = local.dns_authorizations_map

  name        = each.value.name
  project     = each.value.project_id
  location    = each.value.location
  domain      = each.value.domain
  description = each.value.description
  labels      = each.value.labels
}

# ------------------------------------------------------------------------------
# Certificate Issuance Configs (Bridge between Certificate Manager & CAS)
# ------------------------------------------------------------------------------
resource "google_certificate_manager_certificate_issuance_config" "issuance_configs" {
  for_each = local.issuance_configs_map

  name                       = each.value.name
  project                    = each.value.project_id
  location                   = each.value.location
  description                = each.value.description
  lifetime                   = each.value.lifetime
  rotation_window_percentage = each.value.rotation_window_percentage
  key_algorithm              = each.value.key_algorithm

  certificate_authority_config {
    certificate_authority_service_config {
      ca_pool = (
        startswith(each.value.ca_pool, "projects/") ?
        each.value.ca_pool :
        try(google_privateca_ca_pool.pools[each.value.ca_pool].id, each.value.ca_pool)
      )
    }
  }

  labels = each.value.labels

  depends_on = [
    google_privateca_ca_pool.pools,
    google_privateca_certificate_authority.authorities
  ]
}

# ------------------------------------------------------------------------------
# Managed & Self-Managed TLS Certificates
# ------------------------------------------------------------------------------
resource "google_certificate_manager_certificate" "certificates" {
  for_each = local.certificates_map

  name        = each.value.name
  project     = each.value.project_id
  location    = each.value.location
  description = each.value.description
  scope       = each.value.scope

  dynamic "managed" {
    for_each = each.value.is_managed ? [1] : []
    content {
      domains = length(each.value.domains) > 0 ? each.value.domains : null
      dns_authorizations = length(each.value.dns_auths) > 0 ? [
        for d in each.value.dns_auths : (
          startswith(d, "projects/") ? d : try(google_certificate_manager_dns_authorization.dns_auths[d].id, d)
        )
      ] : null

      issuance_config = each.value.issuance_cfg != null ? (
        startswith(each.value.issuance_cfg, "projects/") ?
        each.value.issuance_cfg :
        try(google_certificate_manager_certificate_issuance_config.issuance_configs[each.value.issuance_cfg].id, each.value.issuance_cfg)
      ) : null
    }
  }

  dynamic "self_managed" {
    for_each = each.value.is_self_managed ? [1] : []
    content {
      pem_certificate = each.value.pem_cert
      pem_private_key = each.value.pem_key
    }
  }

  labels = each.value.labels

  depends_on = [
    google_certificate_manager_dns_authorization.dns_auths,
    google_certificate_manager_certificate_issuance_config.issuance_configs
  ]
}

# ------------------------------------------------------------------------------
# Certificate Maps (Decoupled TLS Container for HTTPS Load Balancers)
# ------------------------------------------------------------------------------
resource "google_certificate_manager_certificate_map" "maps" {
  for_each = local.certificate_maps_map

  name        = each.value.name
  project     = each.value.project_id
  description = each.value.description
  labels      = each.value.labels
}

# ------------------------------------------------------------------------------
# Certificate Map Entries (Hostname & Wildcard SNI Bindings)
# ------------------------------------------------------------------------------
resource "google_certificate_manager_certificate_map_entry" "entries" {
  for_each = local.certificate_map_entries_map

  name        = each.value.entry_id
  map         = google_certificate_manager_certificate_map.maps[each.value.map_name].name
  project     = each.value.project_id
  description = each.value.description
  hostname    = each.value.hostname
  matcher     = each.value.matcher

  certificates = [
    for c in each.value.certificates : (
      startswith(c, "projects/") ?
      c :
      try(google_certificate_manager_certificate.certificates[c].id, c)
    )
    if c != null
  ]

  labels = each.value.labels

  depends_on = [
    google_certificate_manager_certificate.certificates,
    google_certificate_manager_certificate_map.maps
  ]
}
