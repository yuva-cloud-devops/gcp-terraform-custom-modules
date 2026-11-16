# ==============================================================================
# HIERARCHICAL FIREWALL MODULE: POLICY RULES
# ==============================================================================
# Iterates through configured firewall rules, dynamically constructing Layer 4
# protocols/ports, directional match blocks (INGRESS/EGRESS), and logging configurations.
# ==============================================================================

resource "google_compute_firewall_policy_rule" "rules" {
  for_each = local.rules_map

  firewall_policy = google_compute_firewall_policy.policy.id
  priority        = each.value.priority
  direction       = each.value.direction
  action          = each.value.action
  description     = lookup(each.value, "description", null)
  enable_logging  = lookup(each.value, "enable_logging", false)

  # Directional Match Specification
  match {
    src_ip_ranges  = each.value.direction == "INGRESS" ? lookup(each.value, "source_ranges", null) : null
    dest_ip_ranges = each.value.direction == "EGRESS" ? lookup(each.value, "destination_ranges", null) : null

    # Dynamic Layer 4 protocol and port configurations (tcp, udp, icmp, esp, all)
    dynamic "layer4_configs" {
      for_each = lookup(each.value, "layer4_configs", [])
      content {
        ip_protocol = layer4_configs.value.ip_protocol
        ports       = lookup(layer4_configs.value, "ports", null)
      }
    }
  }
}


