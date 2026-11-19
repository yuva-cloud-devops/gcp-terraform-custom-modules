# ==============================================================================
# Outputs: Edge Security Setup Example
# ==============================================================================

output "cloud_armor_policies" {
  description = "Created Cloud Armor security policies."
  value       = module.edge_security.cloud_armor_policies
}

output "cloud_ids_endpoints" {
  description = "Created Cloud IDS inspection endpoints."
  value       = module.edge_security.cloud_ids_endpoints
}

output "summary" {
  description = "Summary count of provisioned edge security resources."
  value       = module.edge_security.summary
}
