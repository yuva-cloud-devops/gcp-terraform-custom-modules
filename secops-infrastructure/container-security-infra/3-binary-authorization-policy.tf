# ==============================================================================
# Binary Authorization Deploy-time Policy & Cluster Admission Rules
# ==============================================================================

resource "google_binary_authorization_policy" "policy" {
  count = local.has_policy ? 1 : 0

  project                       = local.policy_config.project_id
  description                   = local.policy_config.description
  global_policy_evaluation_mode = local.policy_config.global_policy_evaluation_mode

  dynamic "admission_whitelist_patterns" {
    for_each = local.policy_config.admission_whitelist_patterns
    content {
      name_pattern = admission_whitelist_patterns.value
    }
  }

  default_admission_rule {
    evaluation_mode  = local.policy_config.default_admission_rule.evaluation_mode
    enforcement_mode = local.policy_config.default_admission_rule.enforcement_mode
    require_attestations_by = (
      local.policy_config.default_admission_rule.evaluation_mode == "REQUIRE_ATTESTATION" ?
      local.policy_config.default_admission_rule.require_attestations_by :
      null
    )
  }

  dynamic "cluster_admission_rules" {
    for_each = local.policy_config.cluster_admission_rules
    content {
      cluster          = cluster_admission_rules.value.cluster
      evaluation_mode  = cluster_admission_rules.value.evaluation_mode
      enforcement_mode = cluster_admission_rules.value.enforcement_mode
      require_attestations_by = (
        cluster_admission_rules.value.evaluation_mode == "REQUIRE_ATTESTATION" ?
        cluster_admission_rules.value.require_attestations_by :
        null
      )
    }
  }

  depends_on = [
    google_binary_authorization_attestor.attestors
  ]
}
