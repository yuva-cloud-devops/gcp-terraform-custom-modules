# ==============================================================================
# Outputs: Zero-Trust Security Infrastructure (IAP & WIF)
# ==============================================================================

output "workload_identity_pools" {
  description = "Map of created Workload Identity Federation Pools."
  value = {
    for k, p in google_iam_workload_identity_pool.pools : k => {
      id           = p.id
      name         = p.name
      pool_id      = p.workload_identity_pool_id
      state        = p.state
      display_name = p.display_name
    }
  }
}

output "workload_identity_providers" {
  description = "Map of created Workload Identity Providers."
  value = {
    for k, pr in google_iam_workload_identity_pool_provider.providers : k => {
      id          = pr.id
      name        = pr.name
      provider_id = pr.workload_identity_pool_provider_id
      state       = pr.state
    }
  }
}

output "service_accounts" {
  description = "Map of managed WIF Service Accounts."
  value = {
    for k, sa in google_service_account.wif_sa : k => {
      id         = sa.id
      name       = sa.name
      email      = sa.email
      unique_id  = sa.unique_id
      account_id = sa.account_id
    }
  }
}

output "iap_firewall_rule" {
  description = "Details of the provisioned IAP TCP Forwarding firewall rule."
  value = length(google_compute_firewall.iap_tcp_forwarding) > 0 ? {
    id            = google_compute_firewall.iap_tcp_forwarding[0].id
    name          = google_compute_firewall.iap_tcp_forwarding[0].name
    network       = google_compute_firewall.iap_tcp_forwarding[0].network
    source_ranges = google_compute_firewall.iap_tcp_forwarding[0].source_ranges
  } : null
}

output "iap_tunnel_accessors" {
  description = "Map of members granted IAP Tunnel Resource Accessor permissions."
  value = {
    for k, a in google_iap_tunnel_iam_member.tunnel_accessors : k => {
      member    = a.member
      role      = a.role
      condition = a.condition
    }
  }
}

output "iap_backend_accessors" {
  description = "Map of members granted IAP HTTPS Web Backend Accessor permissions."
  value = {
    for k, a in google_iap_web_backend_service_iam_member.backend_accessors : k => {
      backend_service = a.web_backend_service
      member          = a.member
      role            = a.role
    }
  }
}

output "summary" {
  description = "Summary count of provisioned Zero Trust infrastructure resources."
  value = {
    wif_pools_count       = length(google_iam_workload_identity_pool.pools)
    wif_providers_count   = length(google_iam_workload_identity_pool_provider.providers)
    wif_sa_count          = length(google_service_account.wif_sa)
    iap_tunnel_accessors  = length(google_iap_tunnel_iam_member.tunnel_accessors)
    iap_backend_accessors = length(google_iap_web_backend_service_iam_member.backend_accessors)
    iap_firewall_enabled  = length(google_compute_firewall.iap_tcp_forwarding) > 0
  }
}
