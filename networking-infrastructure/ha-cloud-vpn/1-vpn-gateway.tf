# ==============================================================================
# HA CLOUD VPN MODULE: GCP HA VPN GATEWAY
# ==============================================================================
# Provisions regional High Availability (HA) VPN Gateways with dual redundant
# public interfaces (Interface 0 and Interface 1) providing 99.99% service availability.
# ==============================================================================

resource "google_compute_ha_vpn_gateway" "gateway" {
  for_each = local.gateways_map

  project     = local.project_id
  name        = each.value.name
  region      = lookup(each.value, "region", local.default_region)
  network     = local.network_self_link
  description = lookup(each.value, "description", "HA VPN Gateway ${each.value.name}")
}
