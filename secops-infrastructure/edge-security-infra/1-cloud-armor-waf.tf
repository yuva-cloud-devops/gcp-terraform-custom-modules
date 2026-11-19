# ==============================================================================
# 1. Cloud Armor Web Application Firewall (WAF) & DDoS Protection
# ==============================================================================
# Provisions enterprise Cloud Armor security policies, OWASP Top 10 preconfigured
# WAF rules, IP allow/deny lists, Geo-fencing CEL expressions, Layer 7 Adaptive
# Protection (ML anomaly detection), and Layer 7 rate-limiting/throttling.
# ==============================================================================

resource "google_compute_security_policy" "policies" {
  for_each = local.armor_policies_map

  name        = each.value.name
  project     = each.value.project_id
  description = each.value.description
  type        = each.value.type

  # ----------------------------------------------------------------------------
  # Layer 7 Adaptive Protection (Machine Learning DDoS & Threat Defense)
  # ----------------------------------------------------------------------------
  dynamic "adaptive_protection_config" {
    for_each = each.value.adaptive_protection ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable = true
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Advanced Inspection Options (JSON payload parsing & logging)
  # ----------------------------------------------------------------------------
  advanced_options_config {
    json_parsing = each.value.json_parsing
    log_level    = each.value.log_level
  }

  # ----------------------------------------------------------------------------
  # Custom Security Rules (OWASP WAF, Geo-fencing, IP Allow/Deny, Rate Limits)
  # ----------------------------------------------------------------------------
  dynamic "rule" {
    for_each = [
      for r in local.armor_rules_list : r
      if r.policy_name == each.value.name
    ]
    content {
      action      = rule.value.action
      priority    = rule.value.priority
      description = rule.value.description
      preview     = rule.value.preview

      match {
        versioned_expr = rule.value.match_type == "ip" ? "SRC_IPS_V1" : null

        dynamic "config" {
          for_each = rule.value.match_type == "ip" ? [1] : []
          content {
            src_ip_ranges = rule.value.src_ip_ranges
          }
        }

        dynamic "expr" {
          for_each = rule.value.match_type != "ip" ? [1] : []
          content {
            expression = rule.value.expression
          }
        }
      }

      # Optional Rate Limiting & Throttling
      dynamic "rate_limit_options" {
        for_each = rule.value.rate_limit_options != null ? [rule.value.rate_limit_options] : []
        content {
          conform_action      = try(rate_limit_options.value.conform_action, "allow")
          exceed_action       = try(rate_limit_options.value.exceed_action, "deny(429)")
          enforce_on_key      = try(rate_limit_options.value.enforce_on_key, "IP")
          enforce_on_key_name = try(rate_limit_options.value.enforce_on_key_name, null)

          rate_limit_threshold {
            count        = rate_limit_options.value.rate_limit_threshold.count
            interval_sec = rate_limit_options.value.rate_limit_threshold.interval_sec
          }

          dynamic "ban_threshold" {
            for_each = try(rate_limit_options.value.ban_threshold, null) != null ? [rate_limit_options.value.ban_threshold] : []
            content {
              count        = ban_threshold.value.count
              interval_sec = ban_threshold.value.interval_sec
            }
          }

          ban_duration_sec = try(rate_limit_options.value.ban_duration_sec, null)
        }
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Default Catch-all Rule (Priority 2147483647)
  # ----------------------------------------------------------------------------
  rule {
    action      = each.value.default_rule_action
    priority    = 2147483647
    description = "Default catch-all rule"

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
