# 4. Loop: Cloud NAT Gateways
resource "google_compute_router_nat" "nats" {
  for_each                           = local.nats
  project                            = local.project_id
  name                               = each.value.nat_name
  router                             = google_compute_router.routers[each.key].name
  region                             = each.value.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  # Dynamic log_config block
  dynamic "log_config" {
    for_each = each.value.log_filter != null ? [1] : []
    content {
      enable = true
      filter = each.value.log_filter
    }
  }
}
