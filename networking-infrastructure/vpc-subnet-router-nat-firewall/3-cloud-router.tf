# 3. Loop: Cloud Routers (one per NAT per VPC)
resource "google_compute_router" "routers" {
  for_each = local.nats
  project  = local.project_id
  name     = each.value.router_name
  region   = each.value.region
  network  = google_compute_network.vpcs[each.value.vpc_name].id
}
