# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Ingests and normalizes YAML configurations for:
#   1. Certificate Authority Service (CAS): CA Pools & CAs
#   2. Certificate Manager: DNS Authorizations, Issuance Configs, Certs & Maps
#   3. Cloud Data Loss Prevention (DLP): Inspect & De-identify Templates, Triggers
# ==============================================================================

locals {
  # ----------------------------------------------------------------------------
  # Raw Configuration Input (File Path or Inline YAML String)
  # ----------------------------------------------------------------------------
  raw_config = yamldecode(
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? (
        try(trimspace(file(var.config_file_path)), "") != "" ? file(var.config_file_path) : "{}"
      ) : "{}"
    )
  )

  # Support optional wrapper root key "pki_data_security" or "pki_data_security_infra"
  raw_root = try(local.raw_config.pki_data_security, try(local.raw_config.pki_data_security_infra, local.raw_config))

  # Global Defaults
  default_project_id = try(local.raw_root.project_id, null)
  default_location   = try(local.raw_root.location, "asia-south1")
  common_labels      = try(local.raw_root.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Certificate Authority Service (CAS) Pools
  # ----------------------------------------------------------------------------
  raw_ca_pools = try(local.raw_root.ca_pools, {})

  ca_pools_map = {
    for k, v in local.raw_ca_pools : try(v.name, tostring(k)) => {
      name             = try(v.name, tostring(k))
      project_id       = try(v.project_id, local.default_project_id)
      location         = try(v.location, local.default_location)
      tier             = upper(try(v.tier, "DEVOPS"))
      description      = try(v.description, "Managed Private CA Pool")
      issuance_policy  = try(v.issuance_policy, null)
      publish_ca_cert  = try(v.publishing_options.publish_ca_cert, try(v.publish_ca_cert, true))
      publish_crl      = upper(try(v.tier, "DEVOPS")) == "DEVOPS" ? false : try(v.publishing_options.publish_crl, try(v.publish_crl, true))
      labels           = merge(local.common_labels, try(v.labels, {}))
    }
  }

  # ----------------------------------------------------------------------------
  # 2. Certificate Authorities (Root & Subordinate CAs)
  # ----------------------------------------------------------------------------
  raw_cas = try(local.raw_root.certificate_authorities, try(local.raw_root.cas, {}))

  certificate_authorities_map = {
    for k, v in local.raw_cas : try(v.ca_id, try(v.name, tostring(k))) => {
      ca_id            = try(v.ca_id, try(v.name, tostring(k)))
      pool_name        = try(v.ca_pool, try(v.pool, try(v.pool_name, tostring(k))))
      project_id       = try(v.project_id, local.default_project_id)
      location         = try(v.location, local.default_location)
      type             = upper(try(v.type, "SELF_SIGNED"))
      lifetime         = try(v.lifetime, "315360000s") # Default 10 years
      algorithm        = try(v.key_spec.algorithm, try(v.algorithm, "RSA_PKCS1_4096_SHA256"))
      
      # Subject Attributes
      common_name      = try(v.subject.common_name, try(v.common_name, "Internal Root Certificate Authority"))
      organization     = try(v.subject.organization, try(v.organization, "SecOps Internal Trust"))
      country_code     = try(v.subject.country_code, try(v.country_code, "IN"))
      org_unit         = try(v.subject.organizational_unit, try(v.organizational_unit, null))
      locality         = try(v.subject.locality, try(v.locality, null))
      province         = try(v.subject.province, try(v.province, null))
      dns_names        = try(v.subject_alt_name.dns_names, try(v.dns_names, []))

      # Deletion lifecycle flags for smooth testing and lifecycle control
      deletion_protection                    = try(v.deletion_protection, false)
      skip_grace_period                      = try(v.skip_grace_period, true)
      ignore_active_certificates_on_deletion = try(v.ignore_active_certificates_on_deletion, true)
      labels                                 = merge(local.common_labels, try(v.labels, {}))
    }
  }

  # ----------------------------------------------------------------------------
  # 3. Certificate Manager: DNS Authorizations
  # ----------------------------------------------------------------------------
  raw_cert_mgr = try(local.raw_root.certificate_manager, {})
  raw_dns_auth = try(local.raw_cert_mgr.dns_authorizations, {})

  dns_authorizations_map = {
    for k, v in local.raw_dns_auth : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      location    = try(v.location, "global")
      domain      = try(v.domain, tostring(k))
      description = try(v.description, "DNS authorization for domain validation")
      labels      = merge(local.common_labels, try(v.labels, {}))
    }
  }

  # ----------------------------------------------------------------------------
  # 4. Certificate Manager: Certificate Issuance Configs (Connects to CAS)
  # ----------------------------------------------------------------------------
  raw_issuance_configs = try(local.raw_cert_mgr.issuance_configs, {})

  issuance_configs_map = {
    for k, v in local.raw_issuance_configs : try(v.name, tostring(k)) => {
      name                       = try(v.name, tostring(k))
      project_id                 = try(v.project_id, local.default_project_id)
      location                   = try(v.location, local.default_location)
      description                = try(v.description, "Certificate Manager issuance config hooked to Private CA Pool")
      ca_pool                    = try(v.ca_pool, try(v.pool, tostring(k)))
      lifetime                   = try(v.lifetime, "1814400s") # Default 21 days
      rotation_window_percentage = try(v.rotation_window_percentage, 34)
      key_algorithm              = try(v.key_algorithm, "ECDSA_P256")
      labels                     = merge(local.common_labels, try(v.labels, {}))
    }
  }

  # ----------------------------------------------------------------------------
  # 5. Certificate Manager: Certificates (Managed & Self-Managed)
  # ----------------------------------------------------------------------------
  raw_certificates = try(local.raw_cert_mgr.certificates, {})

  certificates_map = {
    for k, v in local.raw_certificates : try(v.name, tostring(k)) => {
      name         = try(v.name, tostring(k))
      project_id   = try(v.project_id, local.default_project_id)
      location     = try(v.location, "global")
      description  = try(v.description, "Managed TLS Certificate")
      scope        = try(v.scope, null)
      
      # Managed cert config
      is_managed   = can(v.managed) || (!can(v.self_managed))
      domains      = try(v.managed.domains, try(v.domains, []))
      dns_auths    = try(v.managed.dns_authorizations, try(v.dns_authorizations, []))
      issuance_cfg = try(v.managed.issuance_config, try(v.issuance_config, null))
      
      # Self-managed cert config (PEM)
      is_self_managed = can(v.self_managed)
      pem_cert        = try(v.self_managed.pem_certificate, null)
      pem_key         = try(v.self_managed.pem_private_key, null)

      labels       = merge(local.common_labels, try(v.labels, {}))
    }
  }

  # ----------------------------------------------------------------------------
  # 6. Certificate Manager: Certificate Maps & Map Entries
  # ----------------------------------------------------------------------------
  raw_cert_maps = try(local.raw_cert_mgr.certificate_maps, {})

  certificate_maps_map = {
    for k, v in local.raw_cert_maps : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      description = try(v.description, "Certificate Map for HTTPS Load Balancers")
      labels      = merge(local.common_labels, try(v.labels, {}))
      entries     = try(v.entries, {})
    }
  }

  # Flatten Map Entries across all Certificate Maps
  certificate_map_entries_map = merge([
    for map_key, map_val in local.certificate_maps_map : {
      for entry_k, entry_v in map_val.entries : "${map_key}/${try(entry_v.name, tostring(entry_k))}" => {
        entry_id     = try(entry_v.name, tostring(entry_k))
        map_name     = map_val.name
        project_id   = map_val.project_id
        description  = try(entry_v.description, "Certificate Map Entry")
        hostname     = try(entry_v.hostname, null)
        matcher      = try(entry_v.matcher, null)
        certificates = try(entry_v.certificates, [try(entry_v.certificate, null)])
        labels       = map_val.labels
      }
    }
  ]...)

  # ----------------------------------------------------------------------------
  # 7. Cloud Data Loss Prevention (DLP): Inspect Templates
  # ----------------------------------------------------------------------------
  raw_dlp = try(local.raw_root.dlp, {})
  raw_inspect_templates = try(local.raw_dlp.inspect_templates, {})

  inspect_templates_map = {
    for k, v in local.raw_inspect_templates : try(v.template_id, try(v.name, tostring(k))) => {
      template_id           = try(v.template_id, try(v.name, tostring(k)))
      project_id            = try(v.project_id, local.default_project_id)
      location              = try(v.location, "global")
      display_name          = try(v.display_name, try(v.template_id, tostring(k)))
      description           = try(v.description, "Cloud DLP Inspection Template")
      info_types            = try(v.info_types, ["EMAIL_ADDRESS", "CREDIT_CARD_NUMBER", "AUTH_TOKEN", "GCP_API_KEY"])
      min_likelihood           = try(v.min_likelihood, "LIKELY")
      include_quote            = try(v.include_quote, false)
      max_findings_per_item    = try(v.max_findings_per_item, 100)
      max_findings_per_request = try(v.max_findings_per_request, 1000)
    }
  }

  # ----------------------------------------------------------------------------
  # 8. Cloud Data Loss Prevention (DLP): De-identify Templates
  # ----------------------------------------------------------------------------
  raw_deidentify_templates = try(local.raw_dlp.deidentify_templates, {})

  deidentify_templates_map = {
    for k, v in local.raw_deidentify_templates : try(v.template_id, try(v.name, tostring(k))) => {
      template_id         = try(v.template_id, try(v.name, tostring(k)))
      project_id          = try(v.project_id, local.default_project_id)
      location            = try(v.location, "global")
      display_name        = try(v.display_name, try(v.template_id, tostring(k)))
      description         = try(v.description, "Cloud DLP De-identification Template")
      info_types          = try(v.info_types, ["EMAIL_ADDRESS", "CREDIT_CARD_NUMBER", "AUTH_TOKEN"])
      transformation_type = lower(try(v.transformation_type, "mask"))
      mask_character      = try(v.mask_character, "*")
      number_to_mask      = try(v.number_to_mask, 4)
      reverse_order       = try(v.reverse_order, true)
      replace_value       = try(v.replace_value, "[REDACTED]")
    }
  }

  # ----------------------------------------------------------------------------
  # 9. Cloud Data Loss Prevention (DLP): Scheduled Job Triggers
  # ----------------------------------------------------------------------------
  raw_job_triggers = try(local.raw_dlp.job_triggers, {})

  job_triggers_map = {
    for k, v in local.raw_job_triggers : try(v.trigger_id, try(v.name, tostring(k))) => {
      trigger_id               = try(v.trigger_id, try(v.name, tostring(k)))
      project_id               = try(v.project_id, local.default_project_id)
      location                 = try(v.location, "global")
      display_name             = try(v.display_name, try(v.trigger_id, tostring(k)))
      description              = try(v.description, "Cloud DLP Periodic Discovery Job Trigger")
      status                   = upper(try(v.status, "HEALTHY"))
      inspect_template_name    = try(v.inspect_template_name, try(v.inspect_template, null))
      recurrence_period_duration = try(v.schedule, try(v.recurrence_period_duration, "86400s"))
      
      # Storage Targets
      cloud_storage_bucket     = try(v.cloud_storage.bucket, try(v.gcs_bucket, null))
      bigquery_dataset         = try(v.bigquery.dataset_id, try(v.dataset_id, null))
      bigquery_table           = try(v.bigquery.table_id, try(v.table_id, null))
      pubsub_topic             = try(v.pubsub_topic, null)
    }
  }
}
