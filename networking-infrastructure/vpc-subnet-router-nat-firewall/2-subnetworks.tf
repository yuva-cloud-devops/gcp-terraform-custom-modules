# 2. Loop: Subnets across all VPCs
resource "google_compute_subnetwork" "subnets" {
  for_each                 = local.subnets
  project                  = local.project_id
  name                     = each.value.subnet_name
  ip_cidr_range            = each.value.ip_cidr
  region                   = each.value.region
  network                  = google_compute_network.vpcs[each.value.vpc_name].id
  private_ip_google_access = each.value.private_access
  description              = each.value.description
  # Dynamic block for secondary IP ranges
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.name
      ip_cidr_range = secondary_ip_range.value.ip_cidr
    }
  }
}
