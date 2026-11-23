output "compute_summary" {
  description = "Summary counts of all provisioned compute infrastructure components"
  value       = module.compute.compute_summary
}

output "instance_templates" {
  description = "Created Google Compute Instance Templates"
  value       = module.compute.instance_templates
}

output "vm_instances" {
  description = "Created standalone VM instances (both template-derived and custom)"
  value       = module.compute.vm_instances
}

output "health_checks" {
  description = "Created autohealing health checks"
  value       = module.compute.health_checks
}

output "managed_instance_groups" {
  description = "Created Regional and Zonal Managed Instance Groups"
  value       = module.compute.managed_instance_groups
}

output "autoscalers" {
  description = "Created autoscaling policies targeting Managed Instance Groups"
  value       = module.compute.autoscalers
}

output "compute_policies" {
  description = "Created disk snapshot and VM start/stop resource policies"
  value       = module.compute.compute_policies
}
