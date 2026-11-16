# ==============================================================================
# VPC NETWORK PEERING MODULE: OUTPUTS
# ==============================================================================
# Exports peering states, resource IDs, route propagation settings, and counts.
# ==============================================================================

output "local_peerings" {
  description = "Map of all local-to-peer forwarding connections created by this module."
  value = {
    for k, v in google_compute_network_peering.local_to_peer : k => {
      id                                  = v.id
      name                                = v.name
      network                             = v.network
      peer_network                        = v.peer_network
      state                               = v.state
      state_details                       = v.state_details
      export_custom_routes                = v.export_custom_routes
      import_custom_routes                = v.import_custom_routes
      export_subnet_routes_with_public_ip = v.export_subnet_routes_with_public_ip
      import_subnet_routes_with_public_ip = v.import_subnet_routes_with_public_ip
      stack_type                          = v.stack_type
    }
  }
}

output "reverse_peerings" {
  description = "Map of automated reverse peering connections created to complete the bi-directional handshake."
  value = {
    for k, v in google_compute_network_peering.peer_to_local : k => {
      id                                  = v.id
      name                                = v.name
      network                             = v.network
      peer_network                        = v.peer_network
      state                               = v.state
      state_details                       = v.state_details
      export_custom_routes                = v.export_custom_routes
      import_custom_routes                = v.import_custom_routes
      export_subnet_routes_with_public_ip = v.export_subnet_routes_with_public_ip
      import_subnet_routes_with_public_ip = v.import_subnet_routes_with_public_ip
      stack_type                          = v.stack_type
    }
  }
}

output "all_peerings" {
  description = "Consolidated map of all peering connections (both local and reverse)."
  value = merge(
    { for k, v in google_compute_network_peering.local_to_peer : k => {
      id            = v.id
      direction     = "local-to-peer"
      network       = v.network
      peer_network  = v.peer_network
      state         = v.state
      state_details = v.state_details
    } },
    { for k, v in google_compute_network_peering.peer_to_local : "${k}-reverse" => {
      id            = v.id
      direction     = "peer-to-local"
      network       = v.network
      peer_network  = v.peer_network
      state         = v.state
      state_details = v.state_details
    } }
  )
}

output "peering_states" {
  description = "Quick-lookup map of peering names to their operational status (e.g. ACTIVE, INACTIVE)."
  value = merge(
    { for k, v in google_compute_network_peering.local_to_peer : k => v.state },
    { for k, v in google_compute_network_peering.peer_to_local : "${k}-reverse" => v.state }
  )
}

output "total_local_peerings" {
  description = "Total number of local forward peerings created."
  value       = length(google_compute_network_peering.local_to_peer)
}

output "total_reverse_peerings" {
  description = "Total number of reverse peerings created."
  value       = length(google_compute_network_peering.peer_to_local)
}

output "total_peerings_count" {
  description = "Total number of peering resources managed by this module."
  value       = length(google_compute_network_peering.local_to_peer) + length(google_compute_network_peering.peer_to_local)
}
