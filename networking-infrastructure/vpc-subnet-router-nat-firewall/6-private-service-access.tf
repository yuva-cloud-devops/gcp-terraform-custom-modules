# ==============================================================================
# 6. Private Service Access (Reference: terraform-google-modules/network/google)
#    Enables private connectivity for Cloud SQL, Memorystore, Filestore, etc.
# ==============================================================================

resource "google_compute_global_address" "psa_ranges" {
  for_each = local.psa_ranges

  project       = local.project_id
  name          = each.value.name
  description   = each.value.description
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = each.value.address
  prefix_length = each.value.prefix_length
  network       = google_compute_network.vpcs[each.value.vpc_name].id
}

resource "google_service_networking_connection" "psa_connection" {
  for_each = local.psa_connection

  network                 = google_compute_network.vpcs[each.value.vpc_name].id
  service                 = each.value.service
  reserved_peering_ranges = [for k, v in google_compute_global_address.psa_ranges : v.name]
  deletion_policy         = each.value.deletion_policy

  depends_on = [google_compute_global_address.psa_ranges]
}

resource "google_compute_network_peering_routes_config" "psa_routes" {
  for_each = {
    for k, v in local.psa_connection : k => v
    if v.export_custom_routes || v.import_custom_routes
  }

  project              = local.project_id
  peering              = google_service_networking_connection.psa_connection[each.key].peering
  network              = google_compute_network.vpcs[each.value.vpc_name].name
  export_custom_routes = each.value.export_custom_routes
  import_custom_routes = each.value.import_custom_routes
}
