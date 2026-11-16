# ==============================================================================
# PRIVATE SERVICE CONNECT (PSC) MODULE: GOOGLE APIS (GLOBAL)
# ==============================================================================
# Provisions internal global IP addresses and global forwarding rules to access
# Google Cloud APIs privately over a dedicated internal IP address without
# traversing the public internet or requiring external IP addresses on workloads.
# ==============================================================================

# 1. Reserve Global Internal IP Address in the Base VPC
resource "google_compute_global_address" "google_apis_ip" {
  for_each     = local.google_apis_map
  project      = local.project_id
  name         = "${each.value.name}-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = local.network_self_link
  address      = lookup(each.value, "ip_address", null)
  description  = lookup(each.value, "description", "Reserved internal IP for Google APIs PSC endpoint ${each.value.name}")
}

# 2. Global Forwarding Rule pointing to Google APIs target bundle (all-apis or vpc-sc)
resource "google_compute_global_forwarding_rule" "google_apis_rule" {
  for_each              = local.google_apis_map
  project               = local.project_id
  name                  = each.value.name
  target                = lookup(each.value, "target", "all-apis")
  network               = local.network_self_link
  ip_address            = google_compute_global_address.google_apis_ip[each.key].id
  load_balancing_scheme = "" # Required blank string for Private Service Connect
  description           = lookup(each.value, "description", "PSC Global Forwarding Rule for Google APIs (${each.key})")

  # Explicit dependency guarantees IP allocation completes before forwarding rule attachment
  depends_on = [google_compute_global_address.google_apis_ip]
}
