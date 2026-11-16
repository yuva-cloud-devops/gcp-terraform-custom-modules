# ==============================================================================
# CLOUD DNS EXAMPLE: OUTPUTS
# ==============================================================================

output "vpc_network_name" {
  description = "Name of the VPC network bound to private DNS zones."
  value       = google_compute_network.dns_vpc.name
}

output "vpc_network_self_link" {
  description = "Self-link of the VPC network bound to private DNS zones."
  value       = google_compute_network.dns_vpc.self_link
}

output "managed_zones" {
  description = "Map of created Cloud DNS managed zone names to their full resource attributes."
  value       = module.cloud_dns.managed_zones
}

output "zone_dns_names" {
  description = "Map of managed zone names to their fully qualified domain names (dns_name)."
  value       = module.cloud_dns.zone_dns_names
}

output "name_servers" {
  description = "Map of managed zone names to their assigned Cloud DNS name servers."
  value       = module.cloud_dns.name_servers
}

output "records" {
  description = "Map of created DNS record sets keyed by zone/type/name."
  value       = module.cloud_dns.records
}

output "total_zones_count" {
  description = "Total number of Cloud DNS managed zones provisioned."
  value       = module.cloud_dns.total_zones_count
}

output "total_records_count" {
  description = "Total number of DNS record sets provisioned."
  value       = module.cloud_dns.total_records_count
}

