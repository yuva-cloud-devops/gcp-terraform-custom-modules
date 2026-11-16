# ==============================================================================
# HIERARCHICAL FIREWALL EXAMPLE: OUTPUTS
# ==============================================================================

output "policy_id" {
  description = "Resource identifier of the created hierarchical firewall policy."
  value       = module.hierarchical_firewalls.policy_id
}

output "policy_name" {
  description = "Configured short name of the hierarchical firewall policy."
  value       = module.hierarchical_firewalls.policy_name
}

output "attached_target" {
  description = "Target Organization or Folder URI where guardrail policy is attached."
  value       = module.hierarchical_firewalls.attached_target
}

output "association_id" {
  description = "Resource identifier of the policy association."
  value       = module.hierarchical_firewalls.association_id
}

output "configured_rule_priorities" {
  description = "List of configured rule priorities in evaluation order."
  value       = module.hierarchical_firewalls.configured_rule_priorities
}

output "rules_summary" {
  description = "Summary map of provisioned firewall rules."
  value       = module.hierarchical_firewalls.rules_summary
}

