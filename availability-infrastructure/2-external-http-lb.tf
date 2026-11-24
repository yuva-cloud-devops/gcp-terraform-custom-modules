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
# 1. Global Anycast Static IPv4 Address (Dedicated Public Edge Ingress)
# ------------------------------------------------------------------------------
resource "google_compute_global_address" "external_lb" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.create_address && v.ip_address == null
  }

  name        = "${each.value.name}-ip"
  project     = each.value.project_id
  description = "Global Anycast static IPv4 address for ${each.value.name}"
  ip_version  = each.value.ip_version
}

# ------------------------------------------------------------------------------
# 2. Hardened Modern SSL Policy (Optional)
# ------------------------------------------------------------------------------
resource "google_compute_ssl_policy" "external_lb" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.create_ssl_policy
  }

  name            = "${each.value.name}-ssl-policy"
  project         = each.value.project_id
  description     = "Hardened SSL policy for ${each.value.name}"
  min_tls_version = each.value.ssl_policy_config.min_tls_version
  profile         = each.value.ssl_policy_config.profile

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 3. Google-Managed SSL Certificate (Optional Zero-Touch TLS)
# ------------------------------------------------------------------------------
resource "google_compute_managed_ssl_certificate" "external_lb" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if length(v.managed_ssl_certificate_domains) > 0
  }

  name        = "${each.value.name}-cert"
  project     = each.value.project_id
  description = "Google-managed SSL certificate for ${each.value.name}"

  managed {
    domains = each.value.managed_ssl_certificate_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 4. Global Backend Services (MIG Attachment, CDN, Circuit Breakers & Outlier Detection)
# ------------------------------------------------------------------------------
resource "google_compute_backend_service" "external_lb" {
  for_each = local.external_http_lbs

  name        = "${each.value.name}-backend"
  project     = each.value.project_id
  description = each.value.description

  load_balancing_scheme = each.value.load_balancing_scheme
  protocol              = each.value.protocol
  port_name             = each.value.port_name
  timeout_sec           = each.value.timeout_sec

  connection_draining_timeout_sec = each.value.connection_draining_timeout_sec
  session_affinity                = each.value.session_affinity
  locality_lb_policy              = each.value.locality_lb_policy
  security_policy                 = each.value.security_policy

  custom_request_headers  = each.value.custom_request_headers
  custom_response_headers = each.value.custom_response_headers
  compression_mode        = each.value.compression_mode

  # Health Check Resolution (uses created global health check self_link or direct link)
  health_checks = [
    try(
      google_compute_health_check.global[each.value.health_check_key].self_link,
      each.value.health_check_key
    )
  ]

  # Cloud CDN Option (Plug & Play caching)
  enable_cdn = each.value.enable_cdn

  dynamic "cdn_policy" {
    for_each = each.value.enable_cdn && each.value.cdn_policy != null ? [each.value.cdn_policy] : []
    content {
      cache_mode                   = cdn_policy.value.cache_mode
      default_ttl                  = cdn_policy.value.default_ttl
      max_ttl                      = cdn_policy.value.max_ttl
      client_ttl                   = cdn_policy.value.client_ttl
      negative_caching             = cdn_policy.value.negative_caching
      serve_while_stale            = cdn_policy.value.serve_while_stale
      signed_url_cache_max_age_sec = cdn_policy.value.signed_url_cache_max_age_sec

      dynamic "cache_key_policy" {
        for_each = try(cdn_policy.value.cache_key_policy, null) != null ? [cdn_policy.value.cache_key_policy] : []
        content {
          include_host           = try(cache_key_policy.value.include_host, true)
          include_protocol       = try(cache_key_policy.value.include_protocol, true)
          include_query_string   = try(cache_key_policy.value.include_query_string, true)
          query_string_blacklist = try(cache_key_policy.value.query_string_blacklist, null)
          query_string_whitelist = try(cache_key_policy.value.query_string_whitelist, null)
        }
      }
    }
  }

  # Passive Health Check / Outlier Detection (Auto-eject flaky instances)
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

  # Circuit Breakers (Prevent cascade failures under high surge)
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

  # Attach Target MIGs
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

  dynamic "log_config" {
    for_each = each.value.log_config != null && try(each.value.log_config.enable, false) ? [1] : []
    content {
      enable      = true
      sample_rate = try(each.value.log_config.sample_rate, 1.0)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 5. Global URL Map
# ------------------------------------------------------------------------------
resource "google_compute_url_map" "external_lb" {
  for_each = local.external_http_lbs

  name            = "${each.value.name}-url-map"
  project         = each.value.project_id
  description     = "Global URL map for ${each.value.name}"
  default_service = google_compute_backend_service.external_lb[each.key].self_link
}

# ------------------------------------------------------------------------------
# 6. HTTPS 301 Redirect URL Map (Optional)
# ------------------------------------------------------------------------------
resource "google_compute_url_map" "external_lb_https_redirect" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.http_forward && v.ssl && v.https_redirect
  }

  name        = "${each.value.name}-https-redirect"
  project     = each.value.project_id
  description = "HTTP to HTTPS 301 redirect for ${each.value.name}"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# ------------------------------------------------------------------------------
# 7. Target HTTP Proxy
# ------------------------------------------------------------------------------
resource "google_compute_target_http_proxy" "external_lb" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.http_forward
  }

  name    = "${each.value.name}-http-proxy"
  project = each.value.project_id
  url_map = (
    each.value.ssl && each.value.https_redirect ?
    google_compute_url_map.external_lb_https_redirect[each.key].self_link :
    google_compute_url_map.external_lb[each.key].self_link
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 8. Target HTTPS Proxy (Optional)
# ------------------------------------------------------------------------------
resource "google_compute_target_https_proxy" "external_lb" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.ssl
  }

  name    = "${each.value.name}-https-proxy"
  project = each.value.project_id
  url_map = google_compute_url_map.external_lb[each.key].self_link

  ssl_certificates = concat(
    each.value.ssl_certificates,
    length(each.value.managed_ssl_certificate_domains) > 0 ? [google_compute_managed_ssl_certificate.external_lb[each.key].self_link] : []
  )

  ssl_policy = (
    each.value.create_ssl_policy ?
    google_compute_ssl_policy.external_lb[each.key].self_link :
    each.value.ssl_policy
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 9. Global Forwarding Rule - Port 80 (HTTP)
# ------------------------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "http" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.http_forward
  }

  name                  = "${each.value.name}-http-forwarding-rule"
  project               = each.value.project_id
  description           = "Public HTTP Forwarding Rule for ${each.value.name}"
  load_balancing_scheme = each.value.load_balancing_scheme
  ip_protocol           = "TCP"
  port_range            = each.value.port
  target                = google_compute_target_http_proxy.external_lb[each.key].self_link

  ip_address = (
    each.value.ip_address != null ? each.value.ip_address : (
      each.value.create_address ? google_compute_global_address.external_lb[each.key].address : null
    )
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 10. Global Forwarding Rule - Port 443 (HTTPS)
# ------------------------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "https" {
  for_each = {
    for k, v in local.external_http_lbs : k => v
    if v.ssl
  }

  name                  = "${each.value.name}-https-forwarding-rule"
  project               = each.value.project_id
  description           = "Public HTTPS Forwarding Rule for ${each.value.name}"
  load_balancing_scheme = each.value.load_balancing_scheme
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.external_lb[each.key].self_link

  ip_address = (
    each.value.ip_address != null ? each.value.ip_address : (
      each.value.create_address ? google_compute_global_address.external_lb[each.key].address : null
    )
  )

  lifecycle {
    create_before_destroy = true
  }
}
