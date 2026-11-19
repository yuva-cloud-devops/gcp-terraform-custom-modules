# ==============================================================================
# Outputs: Zero-Trust Security Setup Example
# ==============================================================================

output "workload_identity_pools" {
  description = "Created Workload Identity Federation Pools."
  value       = module.zero_trust.workload_identity_pools
}

output "workload_identity_providers" {
  description = "Created Workload Identity Providers."
  value       = module.zero_trust.workload_identity_providers
}

output "service_accounts" {
  description = "Managed WIF Service Accounts."
  value       = module.zero_trust.service_accounts
}

output "iap_firewall_rule" {
  description = "Provisioned IAP TCP Forwarding firewall rule."
  value       = module.zero_trust.iap_firewall_rule
}

output "iap_tunnel_accessors" {
  description = "Members granted IAP Tunnel Accessor."
  value       = module.zero_trust.iap_tunnel_accessors
}

output "summary" {
  description = "Summary count of provisioned resources."
  value       = module.zero_trust.summary
}
