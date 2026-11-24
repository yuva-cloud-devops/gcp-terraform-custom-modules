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
resource "google_compute_address" "internal_http_lb" {
  for_each = {
    for k, v in local.internal_http_lbs : k => v
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
# 2. Regional Backend Services (INTERNAL_MANAGED Envoy with Circuit Breakers)
# ------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "internal_http_lb" {
  for_each = local.internal_http_lbs

  name        = "${each.value.name}-backend"
  project     = each.value.project_id
  region      = each.value.region
  description = each.value.description

  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = each.value.protocol
  port_name             = each.value.port_name
  timeout_sec           = each.value.timeout_sec

  connection_draining_timeout_sec = each.value.connection_draining_timeout_sec
  session_affinity                = each.value.session_affinity
  locality_lb_policy              = each.value.locality_lb_policy

  # Health Check Resolution (uses created regional health check self_link or direct link)
  health_checks = [
    try(
      google_compute_region_health_check.regional[each.value.health_check_key].self_link,
      each.value.health_check_key
    )
  ]

  dynamic "outlier_detection" {
    for_each = each.value.outlier_detection != null ? [each.value.outlier_detection] : []
    content {
      consecutive_errors           = try(outlier_detection.value.consecutive_errors, null)
      enforcing_consecutive_errors = try(outlier_detection.value.enforcing_consecutive_errors, null)
      enforcing_success_rate       = try(outlier_detection.value.enforcing_success_rate, null)
      max_ejection_percent         = try(outlier_detection.value.max_ejection_percent, null)
      success_rate_minimum_hosts   = try(outlier_detection.value.success_rate_minimum_hosts, null)
      success_rate_request_volume  = try(outlier_detection.value.success_rate_request_volume, null)
      success_rate_stdev_factor    = try(outlier_detection.value.success_rate_stdev_factor, null)

      dynamic "base_ejection_time" {
        for_each = try(outlier_detection.value.base_ejection_time, null) != null ? [outlier_detection.value.base_ejection_time] : []
        content {
          seconds = base_ejection_time.value.seconds
          nanos   = try(base_ejection_time.value.nanos, null)
        }
      }

      dynamic "interval" {
        for_each = try(outlier_detection.value.interval, null) != null ? [outlier_detection.value.interval] : []
        content {
          seconds = interval.value.seconds
          nanos   = try(interval.value.nanos, null)
        }
      }
    }
  }

  dynamic "circuit_breakers" {
    for_each = each.value.circuit_breakers != null ? [each.value.circuit_breakers] : []
    content {
      max_requests_per_connection = try(circuit_breakers.value.max_requests_per_connection, null)
      max_connections             = try(circuit_breakers.value.max_connections, null)
      max_pending_requests        = try(circuit_breakers.value.max_pending_requests, null)
      max_requests                = try(circuit_breakers.value.max_requests, null)
      max_retries                 = try(circuit_breakers.value.max_retries, null)
    }
  }

  dynamic "backend" {
    for_each = each.value.target_migs
    content {
      group                 = backend.value.group
      balancing_mode        = backend.value.balancing_mode
      max_utilization       = backend.value.balancing_mode == "UTILIZATION" ? backend.value.max_utilization : null
      max_rate_per_instance = backend.value.balancing_mode == "RATE" ? backend.value.max_rate_per_instance : null
      capacity_scaler       = backend.value.capacity_scaler
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 3. Regional URL Map
# ------------------------------------------------------------------------------
resource "google_compute_region_url_map" "internal_http_lb" {
  for_each = local.internal_http_lbs

  name            = "${each.value.name}-url-map"
  project         = each.value.project_id
  region          = each.value.region
  description     = "Regional internal URL map for ${each.value.name}"
  default_service = google_compute_region_backend_service.internal_http_lb[each.key].self_link
}

# ------------------------------------------------------------------------------
# 4. Regional Target HTTP Proxy
# ------------------------------------------------------------------------------
resource "google_compute_region_target_http_proxy" "internal_http_lb" {
  for_each = local.internal_http_lbs

  name    = "${each.value.name}-http-proxy"
  project = each.value.project_id
  region  = each.value.region
  url_map = google_compute_region_url_map.internal_http_lb[each.key].self_link

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 5. Regional Internal Forwarding Rule
# ------------------------------------------------------------------------------
resource "google_compute_forwarding_rule" "internal_http_lb" {
  for_each = local.internal_http_lbs

  name                  = "${each.value.name}-forwarding-rule"
  project               = each.value.project_id
  region                = each.value.region
  description           = "Internal L7 Forwarding Rule for ${each.value.name}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = each.value.port
  target                = google_compute_region_target_http_proxy.internal_http_lb[each.key].self_link
  network               = each.value.network
  subnetwork            = each.value.subnetwork

  ip_address = (
    each.value.ip_address != null ? each.value.ip_address : (
      each.value.create_address ? google_compute_address.internal_http_lb[each.key].address : null
    )
  )

  lifecycle {
    create_before_destroy = true
  }
}
