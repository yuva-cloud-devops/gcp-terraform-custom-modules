# ==============================================================================
# CLOUD DNS MODULE: DNS RECORD SETS
# ==============================================================================
# Provisions authoritative resource record sets (A, CNAME, TXT, MX, etc.)
# dynamically across provisioned Cloud DNS managed zones.
# ==============================================================================

resource "google_dns_record_set" "records" {
  for_each     = { for r in local.records_flat : r.key => r }
  project      = local.project_id
  managed_zone = google_dns_managed_zone.zones[each.value.zone_name].name
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas

  depends_on = [google_dns_managed_zone.zones]
}
