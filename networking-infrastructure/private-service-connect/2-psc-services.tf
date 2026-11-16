# ==============================================================================
# PRIVATE SERVICE CONNECT (PSC) MODULE: PUBLISHED SERVICES / SAAS (REGIONAL)
# ==============================================================================
# Provisions regional internal IP addresses and regional forwarding rules that
# connect directly to published producer Service Attachments (e.g. Snowflake,
# Databricks, MongoDB Atlas, or internal producer microservices) across VPCs.
# ==============================================================================

# 1. Reserve Regional Internal IP Address in designated Consumer Subnet
resource "google_compute_address" "service_attachment_ip" {
  for_each     = local.service_attachments_map
  project      = local.project_id
  region       = each.value.region
  name         = "${each.value.name}-ip"
  address_type = "INTERNAL"
  subnetwork   = each.value.subnetwork_id
  address      = each.value.resolved_ip
  description  = lookup(each.value, "description", "Reserved regional internal IP for PSC service attachment ${each.value.name}")
}

# 2. Regional Forwarding Rule pointing to Producer Service Attachment URI
resource "google_compute_forwarding_rule" "service_attachment_rule" {
  for_each              = local.service_attachments_map
  project               = local.project_id
  region                = each.value.region
  name                  = each.value.name
  network               = local.network_self_link
  subnetwork            = each.value.subnetwork_id
  target                = each.value.target_service_attachment
  ip_address            = google_compute_address.service_attachment_ip[each.key].id
  load_balancing_scheme = "" # Required blank string for Private Service Connect
  description           = lookup(each.value, "description", "PSC Regional Forwarding Rule connecting to ${each.value.target_service_attachment}")

  # Explicit dependency guarantees IP allocation completes before forwarding rule attachment
  depends_on = [google_compute_address.service_attachment_ip]
}
