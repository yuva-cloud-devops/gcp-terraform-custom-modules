# ==============================================================================
# 1. VPC Networks (Reference: terraform-google-modules/network/google)
# ==============================================================================

resource "google_compute_network" "vpcs" {
  for_each = local.vpcs

  project                                   = local.project_id
  name                                      = each.value.name
  auto_create_subnetworks                   = each.value.auto_create_subnetworks
  routing_mode                              = each.value.routing_mode
  description                               = each.value.description
  delete_default_routes_on_create           = each.value.delete_default_routes_on_create
  mtu                                       = each.value.mtu
  enable_ula_internal_ipv6                  = each.value.enable_ula_internal_ipv6
  internal_ipv6_range                       = each.value.internal_ipv6_range
  network_firewall_policy_enforcement_order = each.value.network_firewall_policy_enforcement_order
}
