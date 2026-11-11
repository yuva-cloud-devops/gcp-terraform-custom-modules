# 1. Loop: VPC Networks
resource "google_compute_network" "vpcs" {
  for_each                        = local.vpcs
  project                         = local.project_id
  name                            = each.value.name
  auto_create_subnetworks         = false
  routing_mode                    = each.value.routing_mode
  description                     = each.value.description
  delete_default_routes_on_create = each.value.delete_default_routes_on_create
}
