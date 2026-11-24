/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "primary_external_ip" {
  description = "The Global Anycast static IPv4 address of the primary External Application Load Balancer"
  value = length(keys(local.external_http_lbs)) > 0 ? (
    try(
      google_compute_global_forwarding_rule.http[keys(local.external_http_lbs)[0]].ip_address,
      try(google_compute_global_address.external_lb[keys(local.external_http_lbs)[0]].address, null)
    )
  ) : null
}

output "external_http_lbs" {
  description = "Map of all provisioned Global External Application Load Balancers"
  value = {
    for k, v in local.external_http_lbs : k => {
      name             = v.name
      external_ip      = try(google_compute_global_forwarding_rule.http[k].ip_address, try(google_compute_global_address.external_lb[k].address, null))
      backend_service  = google_compute_backend_service.external_lb[k].self_link
      url_map          = google_compute_url_map.external_lb[k].self_link
      http_forwarding  = try(google_compute_global_forwarding_rule.http[k].self_link, null)
      https_forwarding = try(google_compute_global_forwarding_rule.https[k].self_link, null)
      cdn_enabled      = v.enable_cdn
    }
  }
}

output "internal_http_lbs" {
  description = "Map of all provisioned Regional Internal Application Load Balancers"
  value = {
    for k, v in local.internal_http_lbs : k => {
      name            = v.name
      internal_ip     = try(google_compute_forwarding_rule.internal_http_lb[k].ip_address, try(google_compute_address.internal_http_lb[k].address, null))
      backend_service = google_compute_region_backend_service.internal_http_lb[k].self_link
      forwarding_rule = google_compute_forwarding_rule.internal_http_lb[k].self_link
    }
  }
}

output "internal_tcp_lbs" {
  description = "Map of all provisioned Regional Internal L4 Network Load Balancers"
  value = {
    for k, v in local.internal_tcp_lbs : k => {
      name            = v.name
      internal_ip     = try(google_compute_forwarding_rule.internal_tcp_lb[k].ip_address, try(google_compute_address.internal_tcp_lb[k].address, null))
      backend_service = google_compute_region_backend_service.internal_tcp_lb[k].self_link
      forwarding_rule = google_compute_forwarding_rule.internal_tcp_lb[k].self_link
    }
  }
}

output "health_checks" {
  description = "Map of all created centralized health checks (both global and regional)"
  value = merge(
    {
      for k, v in google_compute_health_check.global : k => {
        id          = v.id
        name        = v.name
        self_link   = v.self_link
        is_regional = false
      }
    },
    {
      for k, v in google_compute_region_health_check.regional : k => {
        id          = v.id
        name        = v.name
        self_link   = v.self_link
        is_regional = true
        region      = v.region
      }
    }
  )
}

output "availability_summary" {
  description = "Summary counts of all provisioned availability and load balancing infrastructure"
  value = {
    external_http_lbs      = length(local.external_http_lbs)
    internal_http_lbs      = length(local.internal_http_lbs)
    internal_tcp_lbs       = length(local.internal_tcp_lbs)
    global_health_checks   = length(google_compute_health_check.global)
    regional_health_checks = length(google_compute_region_health_check.regional)
  }
}
