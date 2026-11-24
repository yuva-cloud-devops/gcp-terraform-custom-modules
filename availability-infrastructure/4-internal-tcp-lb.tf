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

# ------------------------------------------------------------------------------
# 1. Regional Static Internal IP Address
# ------------------------------------------------------------------------------
resource "google_compute_address" "internal_tcp_lb" {
  for_each = {
    for k, v in local.internal_tcp_lbs : k => v
    if v.create_address && v.ip_address == null
  }

  name         = "${each.value.name}-ip"
  project      = each.value.project_id
  region       = each.value.region
  description  = "Internal static IP address for ${each.value.name}"
  address_type = "INTERNAL"
  subnetwork   = each.value.subnetwork

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 2. Regional L4 Passthrough Backend Service with Active-Passive Failover
# ------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "internal_tcp_lb" {
  for_each = local.internal_tcp_lbs

  name        = "${each.value.name}-backend"
  project     = each.value.project_id
  region      = each.value.region
  description = each.value.description

  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"

  # Health Check Resolution (uses created regional health check self_link or direct link)
  health_checks = [
    try(
      google_compute_region_health_check.regional[each.value.health_check_key].self_link,
      each.value.health_check_key
    )
  ]

  # Active Primary Backends
  dynamic "backend" {
    for_each = each.value.primary_backends
    content {
      group    = backend.value
      failover = false
    }
  }

  # Passive Failover Backends
  dynamic "backend" {
    for_each = each.value.failover_backends
    content {
      group    = backend.value
      failover = true
    }
  }

  dynamic "failover_policy" {
    for_each = length(each.value.failover_backends) > 0 && each.value.failover_policy != null ? [each.value.failover_policy] : []
    content {
      failover_ratio                       = try(failover_policy.value.failover_ratio, 0.1)
      disable_connection_drain_on_failover = try(failover_policy.value.disable_connection_drain_on_failover, false)
      drop_traffic_if_unhealthy            = try(failover_policy.value.drop_traffic_if_unhealthy, true)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 3. Regional Internal Forwarding Rule
# ------------------------------------------------------------------------------
resource "google_compute_forwarding_rule" "internal_tcp_lb" {
  for_each = local.internal_tcp_lbs

  name                  = "${each.value.name}-forwarding-rule"
  project               = each.value.project_id
  region                = each.value.region
  description           = "Internal L4 Forwarding Rule for ${each.value.name}"
  load_balancing_scheme = "INTERNAL"
  ip_protocol           = "TCP"
  all_ports             = each.value.all_ports ? true : null
  ports                 = each.value.all_ports ? null : each.value.ports
  backend_service       = google_compute_region_backend_service.internal_tcp_lb[each.key].self_link
  network               = each.value.network
  subnetwork            = each.value.subnetwork

  ip_address = (
    each.value.ip_address != null ? each.value.ip_address : (
      each.value.create_address ? google_compute_address.internal_tcp_lb[each.key].address : null
    )
  )

  lifecycle {
    create_before_destroy = true
  }
}
