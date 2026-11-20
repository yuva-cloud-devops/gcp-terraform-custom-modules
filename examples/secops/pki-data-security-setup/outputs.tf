output "ca_pools" {
  description = "Created CAS pools"
  value       = module.pki_data_security.ca_pools
}

output "certificate_authorities" {
  description = "Created Certificate Authorities"
  value       = module.pki_data_security.certificate_authorities
}

output "dns_authorizations" {
  description = "Created Certificate Manager DNS authorizations"
  value       = module.pki_data_security.dns_authorizations
}

output "certificate_maps" {
  description = "Created Certificate Maps"
  value       = module.pki_data_security.certificate_maps
}

output "dlp_inspect_templates" {
  description = "Created DLP inspection templates"
  value       = module.pki_data_security.dlp_inspect_templates
}

output "dlp_deidentify_templates" {
  description = "Created DLP de-identification templates"
  value       = module.pki_data_security.dlp_deidentify_templates
}
