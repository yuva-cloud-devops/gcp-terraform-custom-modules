# ==============================================================================
# 5. Firewall Rules (Reference: terraform-google-modules/network/google)
# ==============================================================================

resource "google_compute_firewall" "rules" {
  for_each = local.firewall_rules

  project     = local.project_id
  name        = each.value.rule_name
  network     = google_compute_network.vpcs[each.value.vpc_name].name
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority
  disabled    = each.value.disabled

  source_ranges           = each.value.source_ranges
  destination_ranges      = each.value.destination_ranges
  source_tags             = each.value.source_tags
  target_tags             = each.value.target_tags
  source_service_accounts = each.value.source_service_accounts
  target_service_accounts = each.value.target_service_accounts

  # Firewall rule logging configuration
  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      metadata = each.value.log_metadata
    }
  }

  # Dynamic ALLOW blocks
  dynamic "allow" {
    for_each = each.value.allows
    content {
      protocol = allow.value.protocol
      ports    = try(allow.value.ports, null)
    }
  }

  # Dynamic DENY blocks
  dynamic "deny" {
    for_each = each.value.denies
    content {
      protocol = deny.value.protocol
      ports    = try(deny.value.ports, null)
    }
  }
}
