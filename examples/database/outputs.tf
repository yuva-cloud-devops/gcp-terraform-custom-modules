output "database_summary" {
  description = "Summary counts of all provisioned database resources"
  value       = module.database.database_summary
}

output "cloud_sql_instances" {
  description = "Created Cloud SQL instances"
  value       = module.database.cloud_sql_instances
}

output "cloud_sql_databases" {
  description = "Created Cloud SQL databases"
  value       = module.database.cloud_sql_databases
}

output "cloud_sql_users" {
  description = "Created Cloud SQL users"
  value       = module.database.cloud_sql_users
}

output "alloydb_clusters" {
  description = "Created AlloyDB clusters"
  value       = module.database.alloydb_clusters
}

output "alloydb_primary_instances" {
  description = "Created AlloyDB primary instances"
  value       = module.database.alloydb_primary_instances
}

output "alloydb_read_pools" {
  description = "Created AlloyDB read pool instances"
  value       = module.database.alloydb_read_pools
}

output "redis_instances" {
  description = "Created Memorystore Redis instances"
  value       = module.database.redis_instances
  sensitive   = true
}

output "firestore_databases" {
  description = "Created Firestore NoSQL databases"
  value       = module.database.firestore_databases
}

output "spanner_instances" {
  description = "Created Cloud Spanner instances"
  value       = module.database.spanner_instances
}

output "spanner_databases" {
  description = "Created Cloud Spanner databases"
  value       = module.database.spanner_databases
}

output "bigtable_instances" {
  description = "Created Cloud Bigtable instances"
  value       = module.database.bigtable_instances
}

output "bigtable_tables" {
  description = "Created Cloud Bigtable tables"
  value       = module.database.bigtable_tables
}
