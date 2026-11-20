output "storage_summary" {
  description = "Summary count of provisioned storage resources"
  value       = module.storage.storage_summary
}

output "buckets" {
  description = "Created Cloud Storage buckets"
  value       = module.storage.buckets
}

output "snapshot_policies" {
  description = "Created snapshot policies"
  value       = module.storage.snapshot_policies
}

output "zonal_disks" {
  description = "Created zonal persistent disks"
  value       = module.storage.zonal_disks
}

output "regional_disks" {
  description = "Created regional persistent disks"
  value       = module.storage.regional_disks
}

output "filestore_instances" {
  description = "Created Filestore NFS instances"
  value       = module.storage.filestore_instances
}
