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
# 1. Global Health Checks (For External L7 Application Load Balancer)
# ------------------------------------------------------------------------------
resource "google_compute_health_check" "global" {
  for_each = local.global_health_checks

  name        = each.value.name
  project     = each.value.project_id
  description = each.value.description

  check_interval_sec  = each.value.check_interval_sec
  timeout_sec         = each.value.timeout_sec
  healthy_threshold   = each.value.healthy_threshold
  unhealthy_threshold = each.value.unhealthy_threshold

  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      enable = true
    }
  }

  dynamic "http_health_check" {
    for_each = each.value.type == "HTTP" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      request_path = each.value.request_path
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "https_health_check" {
    for_each = each.value.type == "HTTPS" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      request_path = each.value.request_path
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "tcp_health_check" {
    for_each = each.value.type == "TCP" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "ssl_health_check" {
    for_each = each.value.type == "SSL" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "grpc_health_check" {
    for_each = each.value.type == "GRPC" ? [1] : []
    content {
      port              = each.value.port
      port_name         = each.value.port_name
      grpc_service_name = each.value.response
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 2. Regional Health Checks (For Internal L7 HTTP and L4 TCP Load Balancers)
# ------------------------------------------------------------------------------
resource "google_compute_region_health_check" "regional" {
  for_each = local.regional_health_checks

  name        = each.value.name
  project     = each.value.project_id
  region      = each.value.region
  description = each.value.description

  check_interval_sec  = each.value.check_interval_sec
  timeout_sec         = each.value.timeout_sec
  healthy_threshold   = each.value.healthy_threshold
  unhealthy_threshold = each.value.unhealthy_threshold

  dynamic "log_config" {
    for_each = each.value.enable_logging ? [1] : []
    content {
      enable = true
    }
  }

  dynamic "http_health_check" {
    for_each = each.value.type == "HTTP" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      request_path = each.value.request_path
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "https_health_check" {
    for_each = each.value.type == "HTTPS" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      request_path = each.value.request_path
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "tcp_health_check" {
    for_each = each.value.type == "TCP" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "ssl_health_check" {
    for_each = each.value.type == "SSL" ? [1] : []
    content {
      port         = each.value.port
      port_name    = each.value.port_name
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "grpc_health_check" {
    for_each = each.value.type == "GRPC" ? [1] : []
    content {
      port              = each.value.port
      port_name         = each.value.port_name
      grpc_service_name = each.value.response
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
