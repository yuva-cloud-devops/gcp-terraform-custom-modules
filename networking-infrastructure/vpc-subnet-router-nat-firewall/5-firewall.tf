# Loop: Firewalls across all VPCs
resource "google_compute_firewall" "rules" {
  for_each = local.firewall_rules

  project     = local.project_id
  name        = "${each.value.vpc_name}-${each.value.rule_name}"
  network     = google_compute_network.vpcs[each.value.vpc_name].name
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority

  source_ranges      = each.value.source_ranges
  destination_ranges = each.value.destination_ranges
  source_tags        = each.value.source_tags
  target_tags        = each.value.target_tags

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
