# ==============================================================================
# CLOUD DNS MODULE: MANAGED ZONES (Private, Forwarding & Peering)
# ==============================================================================
# Dynamically provisions Google Cloud DNS Managed Zones based on YAML configuration,
# configuring private visibility, hybrid forwarding paths, or VPC peering.
# ==============================================================================

resource "google_dns_managed_zone" "zones" {
  for_each    = local.zones_map
  project     = local.project_id
  name        = each.value.name
  dns_name    = each.value.dns_name
  description = lookup(each.value, "description", "Cloud DNS managed zone provisioned by Terraform")
  visibility  = each.value.visibility

  # Private visibility network bindings (active only for private zones with networks defined)
  dynamic "private_visibility_config" {
    for_each = each.value.visibility == "private" && length(local.zone_networks[each.key]) > 0 ? [1] : []
    content {
      dynamic "networks" {
        for_each = local.zone_networks[each.key]
        content {
          network_url = networks.value
        }
      }
    }
  }

  # Dynamic Forwarding Block (Active only if type == 'forwarding')
  dynamic "forwarding_config" {
    for_each = lookup(each.value, "type", "private") == "forwarding" ? [1] : []
    content {
      dynamic "target_name_servers" {
        for_each = lookup(each.value, "target_name_servers", [])
        content {
          ipv4_address    = target_name_servers.value
          forwarding_path = lookup(each.value, "forwarding_path", "default")
        }
      }
    }
  }

  # Dynamic Peering Block (Active only if type == 'peering')
  dynamic "peering_config" {
    for_each = lookup(each.value, "type", "private") == "peering" ? [1] : []
    content {
      target_network {
        network_url = lookup(each.value, "peer_network_url", "")
      }
    }
  }
}
