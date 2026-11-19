# ==============================================================================
# 3. VPC Service Controls (VPC SC) & Access Context Manager (ACM)
# ==============================================================================
# Provisions zero-data-exfiltration perimeters around Google Cloud sensitive APIs
# (Cloud Storage, BigQuery, KMS, Secret Manager) and context-aware Access Levels
# (IP subnetworks, authorized identities, and device health policies).
# Gracefully activates only when 'access_policy_id' is supplied.
# ==============================================================================

# ------------------------------------------------------------------------------
# Access Context Manager Access Levels (Context-Aware Boundary Credentials)
# ------------------------------------------------------------------------------
resource "google_access_context_manager_access_level" "access_levels" {
  for_each = local.access_policy_id != null ? local.access_levels_map : {}

  parent      = "accessPolicies/${local.access_policy_id}"
  name        = "accessPolicies/${local.access_policy_id}/accessLevels/${each.value.name}"
  title       = each.value.title
  description = each.value.description

  basic {
    combining_function = each.value.combining_function

    conditions {
      ip_subnetworks         = length(each.value.ip_subnetworks) > 0 ? each.value.ip_subnetworks : null
      members                = length(each.value.members) > 0 ? each.value.members : null
      regions                = length(each.value.regions) > 0 ? each.value.regions : null
      required_access_levels = length(each.value.required_access_levels) > 0 ? each.value.required_access_levels : null

      dynamic "device_policy" {
        for_each = each.value.device_policy != null ? [each.value.device_policy] : []
        content {
          require_screen_lock              = try(device_policy.value.require_screen_lock, try(device_policy.value.require_screenlock, false))
          require_admin_approval           = try(device_policy.value.require_admin_approval, false)
          require_corp_owned               = try(device_policy.value.require_corp_owned, false)
          allowed_encryption_statuses      = try(device_policy.value.allowed_encryption_statuses, null)
          allowed_device_management_levels = try(device_policy.value.allowed_device_management_levels, null)
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# VPC Service Controls Service Perimeters (Data Loss Prevention Perimeters)
# ------------------------------------------------------------------------------
resource "google_access_context_manager_service_perimeter" "perimeters" {
  for_each = local.access_policy_id != null ? local.perimeters_map : {}

  parent         = "accessPolicies/${local.access_policy_id}"
  name           = "accessPolicies/${local.access_policy_id}/servicePerimeters/${each.value.name}"
  title          = each.value.title
  description    = each.value.description
  perimeter_type = each.value.perimeter_type

  use_explicit_dry_run_spec = each.value.use_explicit_dry_run_spec

  # Active Enforced Perimeter Specification
  status {
    restricted_services = each.value.restricted_services
    resources           = each.value.resources
    access_levels = [
      for al in each.value.access_levels :
      startswith(al, "accessPolicies/") ? al : "accessPolicies/${local.access_policy_id}/accessLevels/${al}"
    ]

    # Ingress Policies (Inbound into Perimeter)
    dynamic "ingress_policies" {
      for_each = try(each.value.ingress_policies, [])
      content {
        ingress_from {
          identity_type = try(ingress_policies.value.from.identities, null) == null ? try(ingress_policies.value.from.identity_type, "ANY_IDENTITY") : null
          identities    = try(ingress_policies.value.from.identities, null)

          dynamic "sources" {
            for_each = try(ingress_policies.value.from.sources, [])
            content {
              access_level = try(sources.value.access_level, null)
              resource     = try(sources.value.resource, null)
            }
          }
        }

        ingress_to {
          resources = try(ingress_policies.value.to.resources, ["*"])

          dynamic "operations" {
            for_each = try(ingress_policies.value.to.operations, [])
            content {
              service_name = try(operations.value.service_name, "*")

              dynamic "method_selectors" {
                for_each = try(operations.value.methods, [])
                content {
                  method = method_selectors.value
                }
              }
            }
          }
        }
      }
    }

    # Egress Policies (Outbound out of Perimeter)
    dynamic "egress_policies" {
      for_each = try(each.value.egress_policies, [])
      content {
        egress_from {
          identity_type = try(egress_policies.value.from.identities, null) == null ? try(egress_policies.value.from.identity_type, "ANY_IDENTITY") : null
          identities    = try(egress_policies.value.from.identities, null)
        }

        egress_to {
          resources = try(egress_policies.value.to.resources, ["*"])

          dynamic "operations" {
            for_each = try(egress_policies.value.to.operations, [])
            content {
              service_name = try(operations.value.service_name, "*")

              dynamic "method_selectors" {
                for_each = try(operations.value.methods, [])
                content {
                  method = method_selectors.value
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_access_context_manager_access_level.access_levels
  ]
}
