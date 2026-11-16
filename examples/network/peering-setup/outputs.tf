# ==============================================================================
# VPC NETWORK PEERING EXAMPLE: OUTPUTS
# ==============================================================================

output "hub_vpc_id" {
  description = "The ID of the provisioned Hub VPC network."
  value       = google_compute_network.hub_vpc.id
}

output "hub_vpc_self_link" {
  description = "The self-link of the provisioned Hub VPC network."
  value       = google_compute_network.hub_vpc.self_link
}

output "spoke_vpc_id" {
  description = "The ID of the provisioned Spoke / Analytics VPC network."
  value       = google_compute_network.spoke_vpc.id
}

output "spoke_vpc_self_link" {
  description = "The self-link of the provisioned Spoke / Analytics VPC network."
  value       = google_compute_network.spoke_vpc.self_link
}

output "local_peerings" {
  description = "Forward peering connections initiated from the Hub VPC."
  value       = module.vpc_peering.local_peerings
}

output "reverse_peerings" {
  description = "Automated reverse peering connections completed in peer networks."
  value       = module.vpc_peering.reverse_peerings
}

output "all_peerings" {
  description = "Consolidated catalog of all peering connections created by the example."
  value       = module.vpc_peering.all_peerings
}

output "peering_states" {
  description = "Operational states (ACTIVE/INACTIVE) of all managed peering connections."
  value       = module.vpc_peering.peering_states
}

output "total_peerings_count" {
  description = "Total number of peering resources created."
  value       = module.vpc_peering.total_peerings_count
}
