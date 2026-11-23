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

resource "google_compute_health_check" "health_checks" {
  for_each = local.health_checks_map

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
      request_path = each.value.request_path
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "https_health_check" {
    for_each = each.value.type == "HTTPS" ? [1] : []
    content {
      port         = each.value.port
      request_path = each.value.request_path
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "tcp_health_check" {
    for_each = each.value.type == "TCP" ? [1] : []
    content {
      port         = each.value.port
      proxy_header = each.value.proxy_header
      response     = each.value.response
    }
  }

  dynamic "grpc_health_check" {
    for_each = each.value.type == "GRPC" ? [1] : []
    content {
      port = each.value.port
    }
  }
}
