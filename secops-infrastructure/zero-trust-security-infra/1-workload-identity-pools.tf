# ==============================================================================
# 1. Workload Identity Federation (WIF) Pools & Providers
# ==============================================================================
# Provisions Workload Identity Pools and Providers (OIDC for GitHub/GitLab, AWS, SAML)
# allowing external workloads to securely exchange identity assertions for short-lived
# Google Cloud credentials without storing long-lived service account keys.
# ==============================================================================

# ------------------------------------------------------------------------------
# Workload Identity Pools
# ------------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "pools" {
  for_each = local.pools_map

  workload_identity_pool_id = each.value.pool_id
  project                   = each.value.project_id
  display_name              = each.value.display_name
  description               = each.value.description
  disabled                  = each.value.disabled
}

# ------------------------------------------------------------------------------
# Workload Identity Providers (OIDC, AWS)
# ------------------------------------------------------------------------------
resource "google_iam_workload_identity_pool_provider" "providers" {
  for_each = local.providers_map

  workload_identity_pool_id          = google_iam_workload_identity_pool.pools[each.value.pool_key].workload_identity_pool_id
  workload_identity_pool_provider_id = each.value.provider_id
  project                            = each.value.project_id
  display_name                       = each.value.display_name
  description                        = each.value.description
  disabled                           = each.value.disabled
  attribute_mapping                  = each.value.attribute_mapping
  attribute_condition                = each.value.attribute_condition

  dynamic "oidc" {
    for_each = each.value.type == "oidc" ? [1] : []
    content {
      issuer_uri        = each.value.issuer_uri
      allowed_audiences = length(each.value.allowed_audiences) > 0 ? each.value.allowed_audiences : null
    }
  }

  dynamic "aws" {
    for_each = each.value.type == "aws" ? [1] : []
    content {
      account_id = each.value.aws_account_id
    }
  }

  depends_on = [
    google_iam_workload_identity_pool.pools
  ]
}
