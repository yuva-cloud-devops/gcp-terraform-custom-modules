/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# ------------------------------------------------------------------------------
# Cloud SQL Outputs
# ------------------------------------------------------------------------------

output "cloud_sql_instances" {
  description = "Map of all provisioned Cloud SQL instances and their connection details."
  value = {
    for k, v in google_sql_database_instance.instances : k => {
      name               = v.name
      connection_name    = v.connection_name
      private_ip_address = v.private_ip_address
      public_ip_address  = v.public_ip_address
      self_link          = v.self_link
      service_account_email_address = v.service_account_email_address
    }
  }
}

output "cloud_sql_databases" {
  description = "Map of created logical Cloud SQL databases."
  value = {
    for k, v in google_sql_database.databases : k => {
      name      = v.name
      instance  = v.instance
      charset   = v.charset
      collation = v.collation
    }
  }
}

output "cloud_sql_users" {
  description = "Map of created Cloud SQL database users (passwords marked sensitive)."
  value = {
    for k, v in google_sql_user.users : k => {
      name     = v.name
      instance = v.instance
      host     = v.host
      type     = v.type
    }
  }
}

# ------------------------------------------------------------------------------
# AlloyDB Outputs
# ------------------------------------------------------------------------------

output "alloydb_clusters" {
  description = "Map of created AlloyDB clusters."
  value = {
    for k, v in google_alloydb_cluster.clusters : k => {
      id          = v.id
      name        = v.name
      cluster_id  = v.cluster_id
      location    = v.location
      uid         = v.uid
    }
  }
}

output "alloydb_primary_instances" {
  description = "Map of AlloyDB primary instances and their connection endpoints."
  value = {
    for k, v in google_alloydb_instance.primary_instances : k => {
      id          = v.id
      name        = v.name
      instance_id = v.instance_id
      ip_address  = v.ip_address
      state       = v.state
    }
  }
}

output "alloydb_read_pools" {
  description = "Map of AlloyDB read pool instances and their connection endpoints."
  value = {
    for k, v in google_alloydb_instance.read_pools : k => {
      id          = v.id
      name        = v.name
      instance_id = v.instance_id
      ip_address  = v.ip_address
      state       = v.state
    }
  }
}

output "alloydb_users" {
  description = "Map of created AlloyDB database users."
  value = {
    for k, v in google_alloydb_user.users : k => {
      name           = v.user_id
      cluster        = v.cluster
      user_type      = v.user_type
      database_roles = v.database_roles
    }
  }
}

# ------------------------------------------------------------------------------
# Memorystore Redis Outputs
# ------------------------------------------------------------------------------

output "redis_instances" {
  description = "Map of Memorystore Redis instances and their connection endpoints."
  value = {
    for k, v in google_redis_instance.instances : k => {
      id                  = v.id
      name                = v.name
      host                = v.host
      port                = v.port
      tier                = v.tier
      current_location_id = v.current_location_id
      auth_string         = v.auth_string
      read_endpoint       = try(v.read_endpoint, null)
      read_endpoint_port  = try(v.read_endpoint_port, null)
    }
  }
  sensitive = true
}

# ------------------------------------------------------------------------------
# Firestore Outputs
# ------------------------------------------------------------------------------

output "firestore_databases" {
  description = "Map of created Firestore / Datastore databases."
  value = {
    for k, v in google_firestore_database.databases : k => {
      id          = v.id
      name        = v.name
      location_id = v.location_id
      type        = v.type
    }
  }
}

# ------------------------------------------------------------------------------
# Cloud Spanner Outputs
# ------------------------------------------------------------------------------

output "spanner_instances" {
  description = "Map of created Cloud Spanner instances."
  value = {
    for k, v in google_spanner_instance.instances : k => {
      id           = v.id
      name         = v.name
      config       = v.config
      display_name = v.display_name
      state        = v.state
    }
  }
}

output "spanner_databases" {
  description = "Map of created Cloud Spanner databases."
  value = {
    for k, v in google_spanner_database.databases : k => {
      id       = v.id
      name     = v.name
      instance = v.instance
      state    = v.state
    }
  }
}

# ------------------------------------------------------------------------------
# Cloud Bigtable Outputs
# ------------------------------------------------------------------------------

output "bigtable_instances" {
  description = "Map of created Cloud Bigtable instances."
  value = {
    for k, v in google_bigtable_instance.instances : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "bigtable_tables" {
  description = "Map of created Cloud Bigtable tables."
  value = {
    for k, v in google_bigtable_table.tables : k => {
      id            = v.id
      name          = v.name
      instance_name = v.instance_name
    }
  }
}

# ------------------------------------------------------------------------------
# Consolidated Summary Output
# ------------------------------------------------------------------------------

output "database_summary" {
  description = "Summary counts of all database resources managed by this module."
  value = {
    cloud_sql_instances_count = length(google_sql_database_instance.instances)
    cloud_sql_databases_count = length(google_sql_database.databases)
    cloud_sql_users_count     = length(google_sql_user.users)
    alloydb_clusters_count    = length(google_alloydb_cluster.clusters)
    alloydb_instances_count   = length(google_alloydb_instance.primary_instances) + length(google_alloydb_instance.read_pools)
    alloydb_users_count       = length(google_alloydb_user.users)
    redis_instances_count     = length(google_redis_instance.instances)
    firestore_databases_count = length(google_firestore_database.databases)
    spanner_instances_count   = length(google_spanner_instance.instances)
    spanner_databases_count   = length(google_spanner_database.databases)
    bigtable_instances_count  = length(google_bigtable_instance.instances)
    bigtable_tables_count     = length(google_bigtable_table.tables)
  }
}
