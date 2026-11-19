# ==============================================================================
# 2. Cloud IDS (Intrusion Detection System) Threat Inspection Endpoints
# ==============================================================================
# Provisions cloud-native Deep Packet Inspection (DPI) powered by Palo Alto Networks
# threat engine to detect network-based malware, exploits, spyware, and command-and-
# control attacks inside Google Cloud VPC networks.
# ==============================================================================

resource "google_cloud_ids_endpoint" "endpoints" {
  for_each = local.cloud_ids_map

  name        = each.value.name
  project     = each.value.project_id
  location    = each.value.location
  network     = each.value.network
  severity    = each.value.severity
  description = each.value.description
}
