# ==============================================================================
# 4. Identity-Aware Proxy (IAP) - Web Applications & Load Balancers
# ==============================================================================
# Enforces Zero Trust context-aware user authentication for internal web portals,
# microservices, and APIs behind Cloud Load Balancing:
# 1. OAuth Brand & OAuth Client provisioning for IAP-secured applications
# 2. Web Backend Service IAM bindings (roles/iap.httpsResourceAccessor) with CEL
# ==============================================================================

# ------------------------------------------------------------------------------
# IAP OAuth Brand (Internal / Enterprise)
# ------------------------------------------------------------------------------
resource "google_iap_brand" "brand" {
  count = local.create_iap_brand ? 1 : 0

  support_email     = local.iap_brand_config.support_email
  application_title = local.iap_brand_config.application_title
  project           = local.iap_brand_config.project_id
}

# ------------------------------------------------------------------------------
# IAP OAuth Clients for Web Applications
# ------------------------------------------------------------------------------
resource "google_iap_client" "clients" {
  for_each = local.create_iap_brand ? local.iap_oauth_clients_map : {}

  display_name = each.value.display_name
  brand        = google_iap_brand.brand[0].name
}

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
