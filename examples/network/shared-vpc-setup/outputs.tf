# ==============================================================================
# BASE VPC NETWORKING OUTPUTS
# ==============================================================================

output "vpc_summary" {
  description = "Summary map of created VPC networks."
  value       = module.vpc-networking.vpcs
}

output "subnet_summary" {
  description = "Summary map of created subnets and secondary ranges."
  value       = module.vpc-networking.subnets
}

output "router_summary" {
  description = "Summary map of provisioned Cloud Routers and BGP configurations."
  value       = module.vpc-networking.routers
}

output "nat_summary" {
  description = "Summary map of provisioned Cloud NAT gateways."
  value       = module.vpc-networking.nat_gateways
}

output "firewall_summary" {
  description = "Summary map of configured VPC firewall rules."
  value       = module.vpc-networking.firewall_rules
}

output "private_service_access_ranges" {
  description = "Summary map of allocated IP ranges for Private Service Access."
  value       = module.vpc-networking.private_service_access_ranges
}

output "private_service_access_connections" {
  description = "Summary map of VPC peering connections for Private Service Access."
  value       = module.vpc-networking.private_service_access_connections
}

# ==============================================================================
# SHARED VPC ORCHESTRATION OUTPUTS
# ==============================================================================

output "host_project_id" {
  description = "The GCP Project ID configured as the Shared VPC Host Project."
  value       = module.shared_vpc.host_project_id
}

output "attached_service_projects" {
  description = "List of GCP Project IDs successfully attached as Shared VPC Service Projects."
  value       = module.shared_vpc.attached_service_projects
}

output "configured_subnet_delegations" {
  description = "Total number of 'roles/compute.networkUser' IAM delegations provisioned across all subnets."
  value       = module.shared_vpc.configured_subnet_delegations
}

output "service_project_attachments" {
  description = "Map of service project IDs to their google_compute_shared_vpc_service_project resource details."
  value       = module.shared_vpc.service_project_attachments
}

