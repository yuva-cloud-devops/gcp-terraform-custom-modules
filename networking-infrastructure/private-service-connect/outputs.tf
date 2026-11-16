# ==============================================================================
# PRIVATE SERVICE CONNECT (PSC) MODULE: OUTPUTS
# ==============================================================================

output "google_apis_endpoints" {
  description = "Detailed map of provisioned Google APIs PSC endpoints and forwarding rules."
  value = {
    for k, v in google_compute_global_forwarding_rule.google_apis_rule : k => {
      name            = v.name
      target          = v.target
      ip_address      = google_compute_global_address.google_apis_ip[k].address
      ip_address_id   = google_compute_global_address.google_apis_ip[k].id
      forwarding_rule = v.id
      self_link       = v.self_link
    }
  }
}

output "service_attachment_endpoints" {
  description = "Detailed map of provisioned SaaS / Producer Service Attachment PSC endpoints."
  value = {
    for k, v in google_compute_forwarding_rule.service_attachment_rule : k => {
      name                      = v.name
      region                    = v.region
      target_service_attachment = v.target
      ip_address                = google_compute_address.service_attachment_ip[k].address
      ip_address_id             = google_compute_address.service_attachment_ip[k].id
      forwarding_rule           = v.id
      self_link                 = v.self_link
    }
  }
}

output "google_apis_ips" {
  description = "Map of Google APIs endpoint names to their reserved internal IP addresses."
  value       = { for k, v in google_compute_global_address.google_apis_ip : k => v.address }
}

output "service_attachment_ips" {
  description = "Map of SaaS service attachment endpoint names to their reserved regional internal IP addresses."
  value       = { for k, v in google_compute_address.service_attachment_ip : k => v.address }
}

output "total_google_apis_endpoints" {
  description = "Total number of Google APIs PSC endpoints created."
  value       = length(google_compute_global_forwarding_rule.google_apis_rule)
}

output "total_service_attachment_endpoints" {
  description = "Total number of SaaS Service Attachment PSC endpoints created."
  value       = length(google_compute_forwarding_rule.service_attachment_rule)
}
