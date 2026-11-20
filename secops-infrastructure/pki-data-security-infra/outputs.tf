# ==============================================================================
# Outputs: PKI & Data Security Infrastructure Module
# ==============================================================================

output "ca_pools" {
  description = "Map of created Certificate Authority Service (CAS) pools."
  value = {
    for k, v in google_privateca_ca_pool.pools : k => {
      id       = v.id
      name     = v.name
      tier     = v.tier
      location = v.location
    }
  }
}

output "certificate_authorities" {
  description = "Map of created Certificate Authorities (Root and Subordinate CAs)."
  value = {
    for k, v in google_privateca_certificate_authority.authorities : k => {
      id                       = v.id
      name                     = v.name
      certificate_authority_id = v.certificate_authority_id
      type                     = v.type
      state                    = v.state
    }
  }
}

output "dns_authorizations" {
  description = "Map of Certificate Manager DNS Authorizations and their required DNS CNAME challenge records."
  value = {
    for k, v in google_certificate_manager_dns_authorization.dns_auths : k => {
      id                  = v.id
      name                = v.name
      domain              = v.domain
      dns_resource_record = v.dns_resource_record
    }
  }
}

output "issuance_configs" {
  description = "Map of Certificate Manager issuance configs hooked to Private CA pools."
  value = {
    for k, v in google_certificate_manager_certificate_issuance_config.issuance_configs : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "certificates" {
  description = "Map of created Certificate Manager certificates."
  value = {
    for k, v in google_certificate_manager_certificate.certificates : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "certificate_maps" {
  description = "Map of created Certificate Maps for HTTPS Load Balancers."
  value = {
    for k, v in google_certificate_manager_certificate_map.maps : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "certificate_map_entries" {
  description = "Map of created Certificate Map Entries linking hostnames to certificates."
  value = {
    for k, v in google_certificate_manager_certificate_map_entry.entries : k => {
      id       = v.id
      name     = v.name
      map      = v.map
      hostname = v.hostname
      matcher  = v.matcher
    }
  }
}

output "dlp_inspect_templates" {
  description = "Map of created Cloud DLP Inspection Templates."
  value = {
    for k, v in google_data_loss_prevention_inspect_template.inspect_templates : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
    }
  }
}

output "dlp_deidentify_templates" {
  description = "Map of created Cloud DLP De-identification Templates."
  value = {
    for k, v in google_data_loss_prevention_deidentify_template.deidentify_templates : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
    }
  }
}

output "dlp_job_triggers" {
  description = "Map of created Cloud DLP Scheduled Job Triggers."
  value = {
    for k, v in google_data_loss_prevention_job_trigger.triggers : k => {
      id           = v.id
      name         = v.name
      display_name = v.display_name
      status       = v.status
    }
  }
}
