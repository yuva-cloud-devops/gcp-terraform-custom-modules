# ==============================================================================
# 4. Identity-Aware Proxy (IAP) - Web Applications & Load Balancers
# ==============================================================================
# Enforces Zero Trust context-aware user authentication for internal web portals,
# microservices, and APIs behind Cloud Load Balancing:
# - Web Backend Service IAM bindings (roles/iap.httpsResourceAccessor) with CEL
#
# Note: Google Cloud has deprecated the programmatic IAP OAuth Admin API
# (google_iap_brand / google_iap_client). In production GCP environments, OAuth
# consent screen brands and clients are configured centrally via the Google Cloud
# Console (APIs & Services > Credentials) or Identity Platform, while Terraform
# enforces least-privilege IAP access control on backend services.
# ==============================================================================

# ------------------------------------------------------------------------------
# Web Backend Service Accessor IAM Bindings (roles/iap.httpsResourceAccessor)
# ------------------------------------------------------------------------------
resource "google_iap_web_backend_service_iam_member" "backend_accessors" {
  for_each = local.iap_web_accessors_map

  web_backend_service = each.value.web_backend_service
  project             = each.value.project_id
  role                = each.value.role
  member              = each.value.member

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = try(condition.value.description, null)
      expression  = condition.value.expression
    }
  }
}
