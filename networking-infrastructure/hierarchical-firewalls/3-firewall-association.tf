# ==============================================================================
# HIERARCHICAL FIREWALL MODULE: POLICY ASSOCIATION
# ==============================================================================
# Associates the configured Hierarchical Firewall Policy with the target Folder
# or Organization node.
# ==============================================================================

resource "google_compute_firewall_policy_association" "association" {
  firewall_policy   = google_compute_firewall_policy.policy.id
  attachment_target = local.parent_target
  name              = "${local.config.policy_name}-association"

  # Explicit dependency guarantees all rules are committed before association takes effect
  depends_on = [google_compute_firewall_policy_rule.rules]
}

