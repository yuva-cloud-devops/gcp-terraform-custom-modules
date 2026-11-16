# ==============================================================================
# HIERARCHICAL FIREWALL MODULE: OUTPUTS
# ==============================================================================

output "policy_id" {
  description = "Resource ID of the created hierarchical firewall policy container."
  value       = google_compute_firewall_policy.policy.id
}

output "policy_name" {
  description = "Short name of the created hierarchical firewall policy."
  value       = google_compute_firewall_policy.policy.short_name
}

output "attached_target" {
  description = "Target Folder or Organization URI where the firewall policy is enforced."
  value       = local.parent_target
}

output "association_id" {
  description = "Resource identifier of the firewall policy association."
  value       = google_compute_firewall_policy_association.association.id
}

output "configured_rule_priorities" {
  description = "List of configured rule priorities in ascending order."
  value       = [for k, v in local.rules_map : v.priority]
}

output "rules_summary" {
  description = "Summary map of all provisioned hierarchical firewall rules."
  value = {
    for k, v in google_compute_firewall_policy_rule.rules : k => {
      priority       = v.priority
      direction      = v.direction
      action         = v.action
      description    = v.description
      enable_logging = v.enable_logging
    }
  }
}

