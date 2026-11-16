# ==============================================================================
# PRIVATE SERVICE CONNECT (PSC) MODULE: LOCAL CONFIGURATION & RESOLUTION
# ==============================================================================
# Decodes the declarative YAML specification, resolves project and network
# parameters, and normalizes endpoint configurations for Google APIs and SaaS.
# ==============================================================================

locals {
  # Decode input YAML configuration file into structured HCL map
  config = yamldecode(file(var.yaml_config_path))

  # Resolve target Project ID and Network Self-Link (priority: YAML, fallback: module variable)
  project_id        = lookup(local.config, "project_id", var.project_id)
  network_self_link = lookup(local.config, "network_self_link", var.network_self_link)

  # Map Google APIs global endpoints by unique endpoint name
  google_apis_map = {
    for ep in lookup(local.config, "google_apis_endpoints", []) : ep.name => ep
  }

  # Map Regional Service Attachment endpoints by unique endpoint name
  # Normalizes subnetwork URI to support both short names and fully qualified self-links
  service_attachments_map = {
    for ep in lookup(local.config, "service_attachment_endpoints", []) : ep.name => merge(ep, {
      subnetwork_id = (
        startswith(ep.subnet_name, "projects/") || startswith(ep.subnet_name, "https://") ?
        ep.subnet_name :
        "projects/${lookup(local.config, "project_id", var.project_id)}/regions/${ep.region}/subnetworks/${ep.subnet_name}"
      )
      resolved_ip = lookup(ep, "ip_address", null) != "" ? lookup(ep, "ip_address", null) : null
    })
  }
}
