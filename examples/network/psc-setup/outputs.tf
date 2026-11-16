# ==============================================================================
# PRIVATE SERVICE CONNECT EXAMPLE: OUTPUTS
# ==============================================================================

output "vpc_network_name" {
  description = "Name of the provisioned VPC network hosting PSC endpoints."
  value       = google_compute_network.psc_vpc.name
}

output "vpc_network_self_link" {
  description = "Self-link of the provisioned VPC network."
  value       = google_compute_network.psc_vpc.self_link
}

output "subnet_name" {
  description = "Name of the consumer subnet hosting regional PSC endpoints."
  value       = google_compute_subnetwork.psc_subnet.name
}

output "subnet_cidr" {
  description = "IP CIDR range of the consumer subnet."
  value       = google_compute_subnetwork.psc_subnet.ip_cidr_range
}

output "google_apis_endpoints" {
  description = "Detailed map of provisioned Google APIs PSC endpoints and forwarding rules."
  value       = module.psc.google_apis_endpoints
}

output "service_attachment_endpoints" {
  description = "Detailed map of provisioned SaaS Service Attachment PSC endpoints."
  value       = module.psc.service_attachment_endpoints
}

output "google_apis_ips" {
  description = "Reserved internal IP addresses for Google APIs."
  value       = module.psc.google_apis_ips
}

output "service_attachment_ips" {
  description = "Reserved regional internal IP addresses for SaaS Service Attachments."
  value       = module.psc.service_attachment_ips
}

output "total_google_apis_endpoints" {
  description = "Total number of Google APIs PSC endpoints created."
  value       = module.psc.total_google_apis_endpoints
}

output "total_service_attachment_endpoints" {
  description = "Total number of SaaS Service Attachment PSC endpoints created."
  value       = module.psc.total_service_attachment_endpoints
}

