# ==============================================================================
# 1. Organization IAM Bindings
# ==============================================================================
# Manages non-authoritative IAM member bindings at the GCP Organization root.
# Roles and principal members are declared under 'organization_iam' in the YAML config.
# ==============================================================================

resource "google_organization_iam_member" "org" {
  for_each = { for item in local.org_iam_flat : item.key => item }

  org_id = local.config.organization_id
  role   = each.value.role
  member = each.value.member
}
