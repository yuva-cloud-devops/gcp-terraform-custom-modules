# ==============================================================================
# SHARED VPC MODULE OUTPUTS
# ==============================================================================

output "host_project_id" {
  description = "The GCP Project ID configured as the Shared VPC Host Project."
  value       = google_compute_shared_vpc_host_project.host.project
}

output "attached_service_projects" {
  description = "List of GCP Project IDs successfully attached as Shared VPC Service Projects."
  value       = [for p in google_compute_shared_vpc_service_project.service_projects : p.service_project]
}

output "configured_subnet_delegations" {
  description = "Total number of 'roles/compute.networkUser' IAM delegations provisioned across all subnets."
  value       = length(local.all_subnet_bindings)
}

output "service_project_attachments" {
  description = "Map of service project IDs to their google_compute_shared_vpc_service_project resource details."
  value = {
    for k, v in google_compute_shared_vpc_service_project.service_projects : k => {
      id              = v.id
      host_project    = v.host_project
      service_project = v.service_project
    }
  }
}
