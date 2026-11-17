# ==============================================================================
# 1. Organization IAM Bindings & Organization Policies
# ==============================================================================
# Manages non-authoritative IAM member bindings at the GCP Organization root.
# Roles and principal members are declared under 'organization_iam' in the YAML config.
# Additionally provisions organization-level boolean policies declared under
# 'org_policies.boolean_policies' using Organization Policy API V2.
# ==============================================================================

resource "google_organization_iam_member" "org" {
  for_each = { for item in local.org_iam_flat : item.key => item }

  org_id = local.config.organization_id
  role   = each.value.role
  member = each.value.member
}

# ==============================================================================
# Organization Policies (Boolean Constraints)
# ==============================================================================
# Enforces org-wide boolean guardrails (e.g., compute.skipDefaultNetworkCreation)
# dynamically via Organization Policy API V2 (google_org_policy_policy).
# ==============================================================================

resource "google_org_policy_policy" "boolean_policies" {
  for_each = {
    for p in lookup(lookup(local.config, "org_policies", {}), "boolean_policies", []) : p.constraint => p
  }

  name   = "organizations/${local.config.organization_id}/policies/${each.value.constraint}"
  parent = "organizations/${local.config.organization_id}"

  spec {
    rules {
      enforce = each.value.enforce ? "TRUE" : "FALSE"
    }
  }
}

