# ==============================================================================
# CLOUD DNS MODULE: OUTPUTS
# ==============================================================================

output "managed_zones" {
  description = "Map of created managed zone names to their full resource attributes."
  value       = google_dns_managed_zone.zones
}

output "zone_ids" {
  description = "Map of created managed zone names to their resource IDs."
  value       = { for k, v in google_dns_managed_zone.zones : k => v.id }
}

output "zone_dns_names" {
  description = "Map of managed zone names to their fully qualified domain names (dns_name)."
  value       = { for k, v in google_dns_managed_zone.zones : k => v.dns_name }
}

output "name_servers" {
  description = "Map of managed zone names to their assigned Cloud DNS name servers."
  value       = { for k, v in google_dns_managed_zone.zones : k => v.name_servers }
}

output "records" {
  description = "Map of created DNS record sets keyed by zone/type/name."
  value       = google_dns_record_set.records
}

output "total_zones_count" {
  description = "Total number of Cloud DNS managed zones provisioned."
  value       = length(google_dns_managed_zone.zones)
}

output "total_records_count" {
  description = "Total number of Cloud DNS record sets provisioned."
  value       = length(local.records_flat)
}
