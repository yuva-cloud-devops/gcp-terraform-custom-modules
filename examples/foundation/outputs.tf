output "organization_id" {
  description = "GCP Organization ID"
  value       = module.foundation_infrastructure.organization_id
}

output "folders" {
  description = "Created folders mapped to resource IDs"
  value       = module.foundation_infrastructure.folders
}

output "projects" {
  description = "Created projects summary"
  value       = module.foundation_infrastructure.projects
}

output "service_accounts" {
  description = "Created custom service accounts"
  value       = module.foundation_infrastructure.service_accounts
}

output "tag_keys" {
  description = "Resource Tag Key IDs"
  value       = module.foundation_infrastructure.tag_keys
}

output "tag_values" {
  description = "Resource Tag Value IDs"
  value       = module.foundation_infrastructure.tag_values
}
