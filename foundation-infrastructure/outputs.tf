# ==============================================================================
# FOUNDATION INFRASTRUCTURE OUTPUTS
# ==============================================================================

# ==============================================================================
# ORGANIZATION & FOLDER OUTPUTS
# ==============================================================================

output "organization_id" {
  description = "The target GCP Organization ID."
  value       = local.config.organization_id
}

output "folders" {
  description = "Map of all created top-level and sub-folders mapped to their GCP resource names (e.g., 'folders/123456789012')."
  value       = local.all_folders
}

# ==============================================================================
# PROJECT FACTORY OUTPUTS
# ==============================================================================

output "projects" {
  description = "Detailed map of created projects including project_id, project_number, and folder_id."
  value = {
    for k, p in google_project.projects : k => {
      project_id     = p.project_id
      project_number = p.number
      folder         = p.folder_id
    }
  }
}

output "project_ids" {
  description = "Lookup map of project name to created GCP project ID."
  value       = { for k, p in google_project.projects : k => p.project_id }
}

output "project_numbers" {
  description = "Lookup map of project name to GCP project number."
  value       = { for k, p in google_project.projects : k => p.number }
}

# ==============================================================================
# SERVICE ACCOUNT OUTPUTS
# ==============================================================================

output "service_accounts" {
  description = "Map of created custom service accounts (keyed as '<project_name>-<account_id>') to their generated email addresses."
  value = {
    for k, sa in google_service_account.sa : k => sa.email
  }
}
