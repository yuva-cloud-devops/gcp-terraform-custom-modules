# ==============================================================================
# FOUNDATION INFRASTRUCTURE OUTPUTS
# ==============================================================================

# ==============================================================================
# 1. ORGANIZATION & FOLDER OUTPUTS
# ==============================================================================

output "organization_id" {
  description = "Target GCP Organization ID"
  value       = local.config.organization_id
}

output "folders" {
  description = "Lookup map from folder display name to GCP resource ID (e.g. 'folders/123456789012')"
  value       = local.all_folders
}

# ==============================================================================
# 2. PROJECT FACTORY OUTPUTS
# ==============================================================================

output "projects" {
  description = "Summary map of created projects including project ID, number, and folder ID"
  value = {
    for k, p in google_project.projects : k => {
      id     = p.project_id
      number = p.number
      folder = p.folder_id
    }
  }
}

# ==============================================================================
# 3. SERVICE ACCOUNT OUTPUTS
# ==============================================================================

output "service_accounts" {
  description = "Map of created custom service account identifiers to their generated email addresses"
  value = {
    for k, sa in google_service_account.sa : k => sa.email
  }
}

# ==============================================================================
# 4. GOVERNANCE & RESOURCE TAG OUTPUTS
# ==============================================================================

output "tag_keys" {
  description = "Lookup map of created Resource Tag keys to their GCP resource IDs"
  value       = { for k, v in google_tags_tag_key.keys : k => v.id }
}

output "tag_values" {
  description = "Lookup map of created Resource Tag values to their GCP resource IDs"
  value       = { for k, v in google_tags_tag_value.values : k => v.id }
}
