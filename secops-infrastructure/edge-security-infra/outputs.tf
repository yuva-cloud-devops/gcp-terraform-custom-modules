# ==============================================================================
# Outputs: Edge Security Infrastructure (Cloud Armor, Cloud IDS, VPC SC)
# ==============================================================================

output "cloud_armor_policies" {
  description = "Map of created Cloud Armor security policies."
  value = {
    for k, p in google_compute_security_policy.policies : k => {
      id          = p.id
      name        = p.name
      self_link   = p.self_link
      fingerprint = p.fingerprint
      type        = p.type
    }
  }
}

output "cloud_ids_endpoints" {
  description = "Map of provisioned Cloud IDS deep packet inspection endpoints."
  value = {
    for k, ids in google_cloud_ids_endpoint.endpoints : k => {
      id                       = ids.id
      name                     = ids.name
      location                 = ids.location
      network                  = ids.network
      endpoint_ip              = ids.endpoint_ip
      endpoint_forwarding_rule = ids.endpoint_forwarding_rule
      severity                 = ids.severity
    }
  }
}

output "access_levels" {
  description = "Map of created Access Context Manager Access Levels."
  value = {
    for k, al in google_access_context_manager_access_level.access_levels : k => {
      name  = al.name
      title = al.title
    }
  }
}

output "service_perimeters" {
  description = "Map of created VPC Service Controls Service Perimeters."
  value = {
    for k, sp in google_access_context_manager_service_perimeter.perimeters : k => {
      name           = sp.name
      title          = sp.title
      perimeter_type = sp.perimeter_type
    }
  }
}

output "summary" {
  description = "Statistical summary count of provisioned edge security resources."
  value = {
    cloud_armor_policies_count = length(google_compute_security_policy.policies)
    cloud_ids_endpoints_count  = length(google_cloud_ids_endpoint.endpoints)
    access_levels_count        = length(google_access_context_manager_access_level.access_levels)
    service_perimeters_count   = length(google_access_context_manager_service_perimeter.perimeters)
  }
}
