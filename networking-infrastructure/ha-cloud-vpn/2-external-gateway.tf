# ==============================================================================
# HA CLOUD VPN MODULE: EXTERNAL VPN GATEWAY
# ==============================================================================
# Represents the remote on-premises VPN router/firewall device or third-party cloud
# gateway (e.g. AWS Virtual Private Gateway, Azure VPN Gateway, Cisco ASA, Palo Alto).
# Deduplicated across gateway declarations to support multi-tunnel topologies.
# ==============================================================================

resource "google_compute_external_vpn_gateway" "external_gateway" {
  for_each = local.external_gateways_map

  project         = local.project_id
  name            = each.key
  redundancy_type = lookup(each.value, "redundancy_type", "TWO_IPS_REDUNDANCY")
  description     = lookup(each.value, "description", "Peer external gateway for ${each.key}")

  # Configure external peer interfaces (1, 2, or 4 public IP endpoints)
  dynamic "interface" {
    for_each = lookup(each.value, "interfaces", [])
    content {
      id         = interface.value.id
      ip_address = interface.value.ip_address
    }
  }
}
