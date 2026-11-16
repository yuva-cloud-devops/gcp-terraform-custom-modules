# ==============================================================================
# HIERARCHICAL FIREWALL MODULE: POLICY CONTAINER
# ==============================================================================
# Provisions the root Hierarchical Firewall Policy container at the specified
# Organization or Folder level.
# ==============================================================================

resource "google_compute_firewall_policy" "policy" {
  parent      = local.parent_target
  short_name  = local.config.policy_name
  description = lookup(local.config, "description", "Hierarchical firewall policy managed by Terraform")
}


