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

locals {
  # ----------------------------------------------------------------------------
  # 1. Configuration Parsing & Context
  # ----------------------------------------------------------------------------
  raw_config = (
    var.yaml_content != null ? yamldecode(var.yaml_content) : (
      var.config_content != null ? yamldecode(var.config_content) : (
        var.config_file_path != null ? yamldecode(file(var.config_file_path)) : {}
      )
    )
  )

  cfg = try(
    local.raw_config.availability_infrastructure,
    try(
      local.raw_config.availability,
      try(local.raw_config.load_balancing, local.raw_config)
    )
  )

  config_dir         = var.config_file_path != null && var.config_file_path != "" ? dirname(var.config_file_path) : path.root
  default_project_id = try(local.raw_config.project_id, try(local.cfg.project_id, null))
  default_region     = try(local.raw_config.region, try(local.cfg.region, "asia-south1"))
  default_network    = try(local.raw_config.network, try(local.cfg.network, "default"))
  default_subnetwork = try(local.raw_config.subnetwork, try(local.cfg.subnetwork, null))
  common_labels      = try(local.raw_config.tags, try(local.cfg.tags, try(local.raw_config.labels, {})))

  # ----------------------------------------------------------------------------
  # 2. Global External Application Load Balancers (Plug & Play Normalization)
  # ----------------------------------------------------------------------------
  raw_external_lb_single = try(local.cfg.external_http_lb, try(local.cfg.load_balancer, null)) != null ? {
    (try(local.cfg.external_http_lb.name, try(local.cfg.load_balancer.name, "glb-web-app"))) = try(local.cfg.external_http_lb, local.cfg.load_balancer)
  } : {}

  raw_external_lbs = merge(
    local.raw_external_lb_single,
    try(local.cfg.external_http_lbs, try(local.cfg.load_balancers, {}))
  )

  external_http_lbs = {
    for k, v in local.raw_external_lbs : try(v.name, tostring(k)) => {
      name                  = try(v.name, tostring(k))
      project_id            = try(v.project_id, local.default_project_id)
      description           = try(v.description, "Global External Application Load Balancer ${try(v.name, tostring(k))}")
      load_balancing_scheme = upper(try(v.load_balancing_scheme, "EXTERNAL_MANAGED")) # EXTERNAL_MANAGED (Envoy) or EXTERNAL (Classic)
      create_address        = try(v.create_address, true)
      ip_address            = try(v.ip_address, try(v.address, null))
      ip_version            = upper(try(v.ip_version, "IPV4"))
      port                  = try(v.port, "80")
      http_forward          = try(v.http_forward, true)
      ssl                   = try(v.ssl, try(v.enable_ssl, false))
      https_redirect        = try(v.https_redirect, false)

      # Managed / Custom SSL
      managed_ssl_certificate_domains = try(v.managed_ssl_certificate_domains, try(v.domains, try(v.ssl_domains, [])))
      ssl_certificates                = try(v.ssl_certificates, try(v.custom_ssl_certificates, []))
      ssl_policy                      = try(v.ssl_policy, null)
      create_ssl_policy               = try(v.create_ssl_policy, false)
      ssl_policy_config = {
        min_tls_version = try(v.ssl_policy_config.min_tls_version, "TLS_1_2")
        profile         = try(v.ssl_policy_config.profile, "MODERN")
      }

      # Backend Configuration (Supports simplified flat structure or nested backend object)
      protocol                        = upper(try(v.protocol, try(v.backend.protocol, "HTTP")))
      port_name                       = try(v.port_name, try(v.backend.port_name, "http"))
      timeout_sec                     = tonumber(try(v.timeout_sec, try(v.backend.timeout_sec, 30)))
      connection_draining_timeout_sec = tonumber(try(v.connection_draining_timeout_sec, try(v.backend.connection_draining_timeout_sec, 30)))
      session_affinity                = upper(try(v.session_affinity, try(v.backend.session_affinity, "NONE")))
      locality_lb_policy              = upper(try(v.locality_lb_policy, try(v.backend.locality_lb_policy, "ROUND_ROBIN")))
      security_policy                 = try(v.security_policy, try(v.backend.security_policy, null))
      custom_request_headers          = try(v.custom_request_headers, try(v.backend.custom_request_headers, null))
      custom_response_headers         = try(v.custom_response_headers, try(v.backend.custom_response_headers, null))
      compression_mode                = try(v.compression_mode, try(v.backend.compression_mode, null))

      # Cloud CDN Plug & Play Option
      enable_cdn = try(v.enable_cdn, try(v.backend.enable_cdn, false))
      cdn_policy = try(v.cdn_policy, try(v.backend.cdn_policy, null)) != null ? {
        cache_mode                   = try(v.cdn_policy.cache_mode, try(v.backend.cdn_policy.cache_mode, "CACHE_ALL_STATIC"))
        default_ttl                  = tonumber(try(v.cdn_policy.default_ttl, try(v.backend.cdn_policy.default_ttl, 3600)))
        max_ttl                      = tonumber(try(v.cdn_policy.max_ttl, try(v.backend.cdn_policy.max_ttl, 86400)))
        client_ttl                   = tonumber(try(v.cdn_policy.client_ttl, try(v.backend.cdn_policy.client_ttl, 3600)))
        negative_caching             = try(v.cdn_policy.negative_caching, try(v.backend.cdn_policy.negative_caching, true))
        serve_while_stale            = tonumber(try(v.cdn_policy.serve_while_stale, try(v.backend.cdn_policy.serve_while_stale, 86400)))
        signed_url_cache_max_age_sec = try(v.cdn_policy.signed_url_cache_max_age_sec, try(v.backend.cdn_policy.signed_url_cache_max_age_sec, null))
        cache_key_policy             = try(v.cdn_policy.cache_key_policy, try(v.backend.cdn_policy.cache_key_policy, null))
      } : null

      # Circuit Breaker / Outlier Detection
      outlier_detection = try(v.outlier_detection, try(v.backend.outlier_detection, null))
      circuit_breakers  = try(v.circuit_breakers, try(v.backend.circuit_breakers, null))

      # Target MIGs Resolution
      target_migs = [
        for mig_ref in flatten([try(v.target_migs, try(v.backend.target_migs, [try(v.target_mig, try(v.backend.target_mig, []))]))]) : {
          group = (
            can(tostring(mig_ref)) ?
            try(var.mig_backend_groups[tostring(mig_ref)], tostring(mig_ref)) :
            try(var.mig_backend_groups[mig_ref.group], mig_ref.group)
          )
          balancing_mode        = upper(try(mig_ref.balancing_mode, try(v.balancing_mode, try(v.backend.balancing_mode, "UTILIZATION"))))
          max_utilization       = try(mig_ref.max_utilization, try(v.max_utilization, try(v.backend.max_utilization, 0.8)))
          max_rate_per_instance = try(mig_ref.max_rate_per_instance, try(v.max_rate_per_instance, try(v.backend.max_rate_per_instance, null)))
          capacity_scaler       = try(mig_ref.capacity_scaler, try(v.capacity_scaler, try(v.backend.capacity_scaler, 1.0)))
        } if mig_ref != null && mig_ref != [] && mig_ref != ""
      ]

      # Inline or Referenced Health Check
      health_check_key = (
        try(v.health_check, try(v.backend.health_check, null)) != null ? "${try(v.name, tostring(k))}-hc" : (
          try(v.health_checks[0], try(v.backend.health_checks[0], null))
        )
      )

      # Inline Health Check Spec (for auto-generation in 1-health-checks.tf)
      inline_health_check = try(v.health_check, try(v.backend.health_check, null))

      # Logging
      log_config = try(v.log_config, try(v.backend.log_config, null))
    }
  }

  # ----------------------------------------------------------------------------
  # 3. Regional Internal Application Load Balancers (Plug & Play Normalization)
  # ----------------------------------------------------------------------------
  raw_internal_http_lb_single = try(local.cfg.internal_http_lb, null) != null ? {
    (try(local.cfg.internal_http_lb.name, "ilb-web-app")) = local.cfg.internal_http_lb
  } : {}

  raw_internal_http_lbs = merge(
    local.raw_internal_http_lb_single,
    try(local.cfg.internal_http_lbs, {})
  )

  internal_http_lbs = {
    for k, v in local.raw_internal_http_lbs : try(v.name, tostring(k)) => {
      name           = try(v.name, tostring(k))
      project_id     = try(v.project_id, local.default_project_id)
      region         = try(v.region, local.default_region)
      network        = try(v.network, local.default_network)
      subnetwork     = try(v.subnetwork, local.default_subnetwork)
      description    = try(v.description, "Regional Internal Application Load Balancer ${try(v.name, tostring(k))}")
      ip_address     = try(v.ip_address, try(v.address, null))
      create_address = try(v.create_address, true)
      port           = try(v.port, "80")

      protocol                        = upper(try(v.protocol, "HTTP"))
      port_name                       = try(v.port_name, "http")
      timeout_sec                     = tonumber(try(v.timeout_sec, 30))
      connection_draining_timeout_sec = tonumber(try(v.connection_draining_timeout_sec, 30))
      session_affinity                = upper(try(v.session_affinity, "NONE"))
      locality_lb_policy              = upper(try(v.locality_lb_policy, "ROUND_ROBIN"))

      outlier_detection = try(v.outlier_detection, null)
      circuit_breakers  = try(v.circuit_breakers, null)

      target_migs = [
        for mig_ref in flatten([try(v.target_migs, [try(v.target_mig, [])])]) : {
          group = (
            can(tostring(mig_ref)) ?
            try(var.mig_backend_groups[tostring(mig_ref)], tostring(mig_ref)) :
            try(var.mig_backend_groups[mig_ref.group], mig_ref.group)
          )
          balancing_mode        = upper(try(mig_ref.balancing_mode, try(v.balancing_mode, "UTILIZATION")))
          max_utilization       = try(mig_ref.max_utilization, try(v.max_utilization, 0.8))
          max_rate_per_instance = try(mig_ref.max_rate_per_instance, try(v.max_rate_per_instance, null))
          capacity_scaler       = try(mig_ref.capacity_scaler, try(v.capacity_scaler, 1.0))
        } if mig_ref != null && mig_ref != [] && mig_ref != ""
      ]

      health_check_key = (
        try(v.health_check, null) != null ? "${try(v.name, tostring(k))}-hc" : (
          try(v.health_checks[0], null)
        )
      )

      inline_health_check = try(v.health_check, null)

      # Optional Regional Envoy Proxy-Only Subnet
      proxy_only_subnet = try(v.proxy_only_subnet, null)
    }
  }

  # ----------------------------------------------------------------------------
  # 4. Regional Internal TCP Load Balancers (Plug & Play Active-Passive)
  # ----------------------------------------------------------------------------
  raw_internal_tcp_lb_single = try(local.cfg.internal_tcp_lb, null) != null ? {
    (try(local.cfg.internal_tcp_lb.name, "nlb-web-app")) = local.cfg.internal_tcp_lb
  } : {}

  raw_internal_tcp_lbs = merge(
    local.raw_internal_tcp_lb_single,
    try(local.cfg.internal_tcp_lbs, {})
  )

  internal_tcp_lbs = {
    for k, v in local.raw_internal_tcp_lbs : try(v.name, tostring(k)) => {
      name           = try(v.name, tostring(k))
      project_id     = try(v.project_id, local.default_project_id)
      region         = try(v.region, local.default_region)
      network        = try(v.network, local.default_network)
      subnetwork     = try(v.subnetwork, local.default_subnetwork)
      description    = try(v.description, "Internal L4 Passthrough Network Load Balancer ${try(v.name, tostring(k))}")
      ip_address     = try(v.ip_address, try(v.address, null))
      create_address = try(v.create_address, true)
      all_ports      = try(v.all_ports, false)
      ports          = try(v.ports, [try(v.port, "3000")])

      # Primary Backends (Active)
      primary_backends = [
        for b in flatten([try(v.primary_backends, try(v.target_migs, [try(v.target_mig, [])]))]) :
        try(var.mig_backend_groups[b], b)
        if b != null && b != [] && b != ""
      ]

      # Failover Backends (Passive)
      failover_backends = [
        for b in flatten([try(v.failover_backends, [try(v.failover_mig, [])])]) :
        try(var.mig_backend_groups[b], b)
        if b != null && b != [] && b != ""
      ]

      failover_policy = try(v.failover_policy, null) != null ? {
        failover_ratio                       = try(v.failover_policy.failover_ratio, 0.1)
        disable_connection_drain_on_failover = try(v.failover_policy.disable_connection_drain_on_failover, false)
        drop_traffic_if_unhealthy            = try(v.failover_policy.drop_traffic_if_unhealthy, true)
      } : null

      health_check_key = (
        try(v.health_check, null) != null ? "${try(v.name, tostring(k))}-hc" : (
          try(v.health_checks[0], null)
        )
      )

      inline_health_check = try(v.health_check, null)

      # Optional Regional Envoy Proxy-Only Subnet
      proxy_only_subnet = try(v.proxy_only_subnet, null)
    }
  }

  # ----------------------------------------------------------------------------
  # 5. Consolidated Health Checks (Global & Regional)
  # ----------------------------------------------------------------------------
  # Collect inline health checks from external LBs (Global)
  inline_global_health_checks = {
    for k, v in local.external_http_lbs : "${v.name}-hc" => {
      name                = "${v.name}-hc"
      project_id          = v.project_id
      description         = "Auto-generated global health check for ${v.name}"
      type                = upper(try(v.inline_health_check.type, "HTTP"))
      port                = tonumber(try(v.inline_health_check.port, 80))
      port_name           = try(v.inline_health_check.port_name, null)
      request_path        = try(v.inline_health_check.request_path, "/")
      proxy_header        = upper(try(v.inline_health_check.proxy_header, "NONE"))
      response            = try(v.inline_health_check.response, null)
      check_interval_sec  = tonumber(try(v.inline_health_check.check_interval_sec, 10))
      timeout_sec         = tonumber(try(v.inline_health_check.timeout_sec, 5))
      healthy_threshold   = tonumber(try(v.inline_health_check.healthy_threshold, 2))
      unhealthy_threshold = tonumber(try(v.inline_health_check.unhealthy_threshold, 3))
      enable_logging      = try(v.inline_health_check.enable_logging, try(v.inline_health_check.logging, false))
    } if v.inline_health_check != null
  }

  # Collect inline health checks from internal HTTP LBs (Regional)
  inline_internal_http_health_checks = {
    for k, v in local.internal_http_lbs : "${v.name}-hc" => {
      name                = "${v.name}-hc"
      project_id          = v.project_id
      region              = v.region
      description         = "Auto-generated regional health check for ${v.name}"
      type                = upper(try(v.inline_health_check.type, "HTTP"))
      port                = tonumber(try(v.inline_health_check.port, 80))
      port_name           = try(v.inline_health_check.port_name, null)
      request_path        = try(v.inline_health_check.request_path, "/")
      proxy_header        = upper(try(v.inline_health_check.proxy_header, "NONE"))
      response            = try(v.inline_health_check.response, null)
      check_interval_sec  = tonumber(try(v.inline_health_check.check_interval_sec, 10))
      timeout_sec         = tonumber(try(v.inline_health_check.timeout_sec, 5))
      healthy_threshold   = tonumber(try(v.inline_health_check.healthy_threshold, 2))
      unhealthy_threshold = tonumber(try(v.inline_health_check.unhealthy_threshold, 3))
      enable_logging      = try(v.inline_health_check.enable_logging, try(v.inline_health_check.logging, false))
    } if v.inline_health_check != null
  }

  # Collect inline health checks from internal TCP LBs (Regional)
  inline_internal_tcp_health_checks = {
    for k, v in local.internal_tcp_lbs : "${v.name}-hc" => {
      name                = "${v.name}-hc"
      project_id          = v.project_id
      region              = v.region
      description         = "Auto-generated regional health check for ${v.name}"
      type                = upper(try(v.inline_health_check.type, "TCP"))
      port                = tonumber(try(v.inline_health_check.port, 3000))
      port_name           = try(v.inline_health_check.port_name, null)
      request_path        = try(v.inline_health_check.request_path, "/")
      proxy_header        = upper(try(v.inline_health_check.proxy_header, "NONE"))
      response            = try(v.inline_health_check.response, null)
      check_interval_sec  = tonumber(try(v.inline_health_check.check_interval_sec, 10))
      timeout_sec         = tonumber(try(v.inline_health_check.timeout_sec, 5))
      healthy_threshold   = tonumber(try(v.inline_health_check.healthy_threshold, 2))
      unhealthy_threshold = tonumber(try(v.inline_health_check.unhealthy_threshold, 3))
      enable_logging      = try(v.inline_health_check.enable_logging, try(v.inline_health_check.logging, false))
    } if v.inline_health_check != null
  }

  # Standalone health checks from yaml
  raw_health_checks = try(local.cfg.health_checks, {})

  standalone_global_health_checks = {
    for k, v in local.raw_health_checks : try(v.name, tostring(k)) => {
      name                = try(v.name, tostring(k))
      project_id          = try(v.project_id, local.default_project_id)
      description         = try(v.description, "Global health check ${try(v.name, tostring(k))}")
      type                = upper(try(v.type, "HTTP"))
      port                = tonumber(try(v.port, 80))
      port_name           = try(v.port_name, null)
      request_path        = try(v.request_path, "/")
      proxy_header        = upper(try(v.proxy_header, "NONE"))
      response            = try(v.response, null)
      check_interval_sec  = tonumber(try(v.check_interval_sec, 5))
      timeout_sec         = tonumber(try(v.timeout_sec, 5))
      healthy_threshold   = tonumber(try(v.healthy_threshold, 2))
      unhealthy_threshold = tonumber(try(v.unhealthy_threshold, 2))
      enable_logging      = try(v.enable_logging, try(v.logging, false))
    } if !try(v.is_regional, false)
  }

  standalone_regional_health_checks = {
    for k, v in local.raw_health_checks : try(v.name, tostring(k)) => {
      name                = try(v.name, tostring(k))
      project_id          = try(v.project_id, local.default_project_id)
      region              = try(v.region, local.default_region)
      description         = try(v.description, "Regional health check ${try(v.name, tostring(k))}")
      type                = upper(try(v.type, "HTTP"))
      port                = tonumber(try(v.port, 80))
      port_name           = try(v.port_name, null)
      request_path        = try(v.request_path, "/")
      proxy_header        = upper(try(v.proxy_header, "NONE"))
      response            = try(v.response, null)
      check_interval_sec  = tonumber(try(v.check_interval_sec, 5))
      timeout_sec         = tonumber(try(v.timeout_sec, 5))
      healthy_threshold   = tonumber(try(v.healthy_threshold, 2))
      unhealthy_threshold = tonumber(try(v.unhealthy_threshold, 2))
      enable_logging      = try(v.enable_logging, try(v.logging, false))
    } if try(v.is_regional, false)
  }

  # Merged health check pools
  global_health_checks = merge(
    local.standalone_global_health_checks,
    local.inline_global_health_checks
  )

  regional_health_checks = merge(
    local.standalone_regional_health_checks,
    local.inline_internal_http_health_checks,
    local.inline_internal_tcp_health_checks
  )

  # ----------------------------------------------------------------------------
  # 6. Cloud CDN Signed URL Keys
  # ----------------------------------------------------------------------------
  raw_cdn_keys = try(local.cfg.cloud_cdn.signed_url_keys, try(local.cfg.signed_url_keys, {}))
  signed_url_keys = {
    for k, v in local.raw_cdn_keys : try(v.name, tostring(k)) => {
      name            = try(v.name, tostring(k))
      project_id      = try(v.project_id, local.default_project_id)
      backend_service = v.backend_service
      key_value       = v.key_value
    }
  }
}
