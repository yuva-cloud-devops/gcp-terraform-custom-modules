# ==============================================================================
# 4. Cloud NAT Gateways (Reference: terraform-google-modules/cloud-nat/google)
# ==============================================================================

resource "google_compute_router_nat" "nats" {
  for_each = local.nats

  project                             = local.project_id
  name                                = each.value.name
  router                              = try(google_compute_router.routers[each.value.router_name].name, each.value.router_name)
  region                              = each.value.region
  nat_ip_allocate_option              = each.value.nat_ip_allocate_option
  nat_ips                             = each.value.nat_ips
  source_subnetwork_ip_ranges_to_nat  = each.value.source_subnetwork_ip_ranges_to_nat
  min_ports_per_vm                    = each.value.min_ports_per_vm
  max_ports_per_vm                    = each.value.enable_dynamic_port_allocation ? each.value.max_ports_per_vm : null
  enable_dynamic_port_allocation      = each.value.enable_dynamic_port_allocation
  enable_endpoint_independent_mapping = each.value.enable_endpoint_independent_mapping

  icmp_idle_timeout_sec            = each.value.icmp_idle_timeout_sec
  tcp_established_idle_timeout_sec = each.value.tcp_established_idle_timeout_sec
  tcp_transitory_idle_timeout_sec  = each.value.tcp_transitory_idle_timeout_sec
  tcp_time_wait_timeout_sec        = each.value.tcp_time_wait_timeout_sec
  udp_idle_timeout_sec             = each.value.udp_idle_timeout_sec

  # Optional custom subnetwork NAT mapping (when source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS")
  dynamic "subnetwork" {
    for_each = each.value.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS" ? each.value.subnetworks : []
    content {
      name                     = try(google_compute_subnetwork.subnets[subnetwork.value.name].id, subnetwork.value.name)
      source_ip_ranges_to_nat  = subnetwork.value.source_ip_ranges_to_nat
      secondary_ip_range_names = contains(subnetwork.value.source_ip_ranges_to_nat, "LIST_OF_SECONDARY_IP_RANGES") ? subnetwork.value.secondary_ip_range_names : null
    }
  }

  # Logging configuration block
  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      enable = each.value.enable_logging
      filter = each.value.log_filter
    }
  }

  depends_on = [google_compute_router.routers]
}
