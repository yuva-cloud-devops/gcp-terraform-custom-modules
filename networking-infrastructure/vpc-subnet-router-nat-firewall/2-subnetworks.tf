# ==============================================================================
# 2. Subnetworks (Reference: terraform-google-modules/network/google)
# ==============================================================================

resource "google_compute_subnetwork" "subnets" {
  for_each = local.subnets

  project                    = local.project_id
  name                       = each.value.subnet_name
  ip_cidr_range              = each.value.ip_cidr
  region                     = each.value.region
  network                    = google_compute_network.vpcs[each.value.vpc_name].id
  private_ip_google_access   = each.value.private_access
  private_ipv6_google_access = each.value.private_ipv6_access
  description                = each.value.description
  purpose                    = each.value.purpose
  role                       = each.value.role
  stack_type                 = each.value.stack_type
  ipv6_access_type           = each.value.ipv6_access_type

  # Dynamic block for Secondary IP Ranges (e.g., GKE Pods & Services)
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  # Dynamic block for VPC Flow Logs
  dynamic "log_config" {
    for_each = each.value.flow_logs_enabled ? [1] : []
    content {
      aggregation_interval = each.value.flow_logs_interval
      flow_sampling        = each.value.flow_logs_sampling
      metadata             = each.value.flow_logs_metadata
      metadata_fields      = each.value.flow_logs_metadata == "CUSTOM_METADATA" ? each.value.flow_logs_metadata_fields : null
      filter_expr          = each.value.flow_logs_filter
    }
  }
}
