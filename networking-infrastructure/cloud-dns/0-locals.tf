# ==============================================================================
# CLOUD DNS MODULE: LOCAL CONFIGURATION & NORMALIZATION
# ==============================================================================
# Decodes the YAML specification, normalizes FQDNs and trailing dots, computes
# network attachments per zone, and prepares deterministic flat record lists.
# ==============================================================================

locals {
  # Decode input YAML configuration file into structured HCL map
  config = yamldecode(file(var.yaml_config_path))

  # Target GCP Project ID (priority: YAML project_id, fallback: var.project_id)
  project_id = lookup(local.config, "project_id", var.project_id)

  # Normalize zones map ensuring valid dns_name with trailing dot
  zones_map = {
    for z in lookup(local.config, "zones", []) : z.name => merge(z, {
      dns_name   = endswith(z.dns_name, ".") ? z.dns_name : "${z.dns_name}."
      visibility = lookup(z, "visibility", lookup(z, "type", "private") == "public" ? "public" : "private")
    })
  }

  # Multi-tier network binding resolution:
  # Priority:
  # 1. Zone-level `networks` or `network_self_link` in YAML
  # 2. Global `networks` or `network_self_link` in YAML
  # 3. Module input `var.network_self_links` or `var.network_self_link`
  zone_networks = {
    for name, z in local.zones_map : name => distinct(compact(concat(
      lookup(z, "networks", []),
      lookup(z, "network_self_link", null) != null ? [z.network_self_link] : [],
      lookup(local.config, "networks", []),
      lookup(local.config, "network_self_link", null) != null ? [local.config.network_self_link] : [],
      var.network_self_links,
      var.network_self_link != null ? [var.network_self_link] : []
    )))
  }

  # Flatten all records across all zones with resilient FQDN derivation
  records_flat = flatten([
    for z_name, z in local.zones_map : [
      for r in lookup(z, "records", []) : {
        zone_name = z_name
        dns_name  = z.dns_name
        # Format fully qualified domain name (FQDN):
        # - "@" or "" maps to the apex zone domain (z.dns_name)
        # - Domain ending with "." preserved as FQDN
        # - Relative subdomains appended with ".${z.dns_name}"
        name = (
          r.name == "@" || r.name == "" ? z.dns_name : (
            endswith(r.name, ".") ? r.name : "${r.name}.${z.dns_name}"
          )
        )
        type    = upper(r.type)
        ttl     = lookup(r, "ttl", 300)
        rrdatas = lookup(r, "rrdatas", [])
        # Deterministic and safe map key (replace '*' with 'wildcard')
        key = "${z_name}/${upper(r.type)}/${replace(r.name, "*", "wildcard")}"
      }
    ]
  ])
}
