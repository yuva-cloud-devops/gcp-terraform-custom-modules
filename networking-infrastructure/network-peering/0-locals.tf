# ==============================================================================
# VPC NETWORK PEERING MODULE: LOCALS & CONFIGURATION PARSER
# ==============================================================================
# Decodes the peering YAML definition, normalizes network self-links,
# injects dynamic runtime overrides, and partitions peerings into forward
# connections and automated reverse handshakes.
# ==============================================================================

locals {
  # 1. Decode YAML configuration file
  raw_config = yamldecode(file(var.yaml_config_path))

  # 2. Resolve local base network self-link (prefers variable, falls back to YAML)
  local_network_self_link = trimspace(
    var.local_network_self_link != "" ? var.local_network_self_link : try(local.raw_config.local_network_self_link, "")
  )

  # 3. Map all defined local peerings with optional runtime overrides
  peerings_map = {
    for p in lookup(local.raw_config, "peerings", []) : p.name => merge(p, {
      peer_network_self_link = trimspace(lookup(
        var.peer_network_overrides,
        p.name,
        lookup(p, "peer_network_self_link", "")
      ))
    })
  }

  # 4. Filter peerings that require the automated bi-directional reverse handshake
  reverse_peerings_map = {
    for k, p in local.peerings_map : k => p
    if lookup(p, "auto_create_reverse_peering", false)
  }
}
