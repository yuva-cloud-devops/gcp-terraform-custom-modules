# ==============================================================================
# 1. Google Cloud Data Access Audit Log Configurations
# ==============================================================================
# Configures Cloud Audit Logs (Admin Read, Data Read, Data Write) across
# Project, Folder, or Organization scopes. Enables full visibility into who
# accessed or modified sensitive data and resources in Google Cloud.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project Scope Data Access Audit Config
# ------------------------------------------------------------------------------
resource "google_project_iam_audit_config" "project_audit" {
  for_each = local.audit_scope == "project" && local.audit_target_id != null ? local.audit_services_map : {}

  project = local.audit_target_id
  service = each.value.service

  dynamic "audit_log_config" {
    for_each = toset(each.value.log_types)
    content {
      log_type         = audit_log_config.value
      exempted_members = length(each.value.exempted_members) > 0 ? each.value.exempted_members : null
    }
  }
}

# ------------------------------------------------------------------------------
# Folder Scope Data Access Audit Config
# ------------------------------------------------------------------------------
resource "google_folder_iam_audit_config" "folder_audit" {
  for_each = local.audit_scope == "folder" && local.audit_target_id != null ? local.audit_services_map : {}

  folder  = local.audit_target_id
  service = each.value.service

  dynamic "audit_log_config" {
    for_each = toset(each.value.log_types)
    content {
      log_type         = audit_log_config.value
      exempted_members = length(each.value.exempted_members) > 0 ? each.value.exempted_members : null
    }
  }
}

# ------------------------------------------------------------------------------
# Organization Scope Data Access Audit Config
# ------------------------------------------------------------------------------
resource "google_organization_iam_audit_config" "org_audit" {
  for_each = (local.audit_scope == "organization" || local.audit_scope == "org") && local.audit_target_id != null ? local.audit_services_map : {}

  org_id  = local.audit_target_id
  service = each.value.service

  dynamic "audit_log_config" {
    for_each = toset(each.value.log_types)
    content {
      log_type         = audit_log_config.value
      exempted_members = length(each.value.exempted_members) > 0 ? each.value.exempted_members : null
    }
  }
}
