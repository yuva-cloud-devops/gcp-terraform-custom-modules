# ==============================================================================
# 3. Identity-Aware Proxy (IAP) - TCP Forwarding & Tunneling
# ==============================================================================
# Enforces Zero Trust access to Compute Engine instances without public IP addresses
# or traditional jump/bastion hosts:
# 1. Automated Google IAP ingress firewall rule (35.235.240.0/20 on ports 22, 3389)
# 2. Project-level Tunnel Resource Accessor IAM bindings with optional CEL conditions
# ==============================================================================

# ------------------------------------------------------------------------------
# Ingress Firewall Rule for Google IAP TCP Forwarding
# ------------------------------------------------------------------------------
resource "google_compute_firewall" "iap_tcp_forwarding" {
  count = local.enable_iap_firewall && local.iap_firewall_config.project_id != null ? 1 : 0

  name                    = local.iap_firewall_config.name
  project                 = local.iap_firewall_config.project_id
  network                 = local.iap_firewall_config.network
  direction               = "INGRESS"
  priority                = 1000
  source_ranges           = ["35.235.240.0/20"] # Official Google Cloud IAP IP netblock
  target_tags             = local.iap_firewall_config.target_tags
  target_service_accounts = local.iap_firewall_config.target_service_accounts

  allow {
    protocol = "tcp"
    ports    = local.iap_firewall_config.ports
  }

  description = "Allows inbound SSH and RDP traffic strictly from Google Identity-Aware Proxy (35.235.240.0/20)"
}

# ------------------------------------------------------------------------------
# IAP Tunnel Resource Accessor IAM Bindings (roles/iap.tunnelResourceAccessor)
# ------------------------------------------------------------------------------
resource "google_iap_tunnel_iam_member" "tunnel_accessors" {
  for_each = local.iap_tcp_accessors_map

  project = each.value.project_id
  role    = each.value.role
  member  = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}
