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

locals {
  # ----------------------------------------------------------------------------
  # 1. Configuration Parsing & Context
  # ----------------------------------------------------------------------------
  raw_config = (
    var.yaml_content != null ? yamldecode(var.yaml_content) : (
      var.config_file_path != null ? yamldecode(file(var.config_file_path)) : {}
    )
  )

  cfg                = try(local.raw_config.database_infrastructure, try(local.raw_config.databases, local.raw_config))
  default_project_id = try(local.cfg.project_id, null)
  default_region     = try(local.cfg.region, "asia-south1")
  default_network    = try(local.cfg.network, "default")

  # ----------------------------------------------------------------------------
  # 2. Cloud SQL (PostgreSQL, MySQL, SQL Server)
  # ----------------------------------------------------------------------------
  raw_cloud_sql = try(local.cfg.cloud_sql, {})
  raw_sql_instances = try(local.raw_cloud_sql.instances, {})

  cloud_sql_instances_map = {
    for k, v in local.raw_sql_instances : try(v.name, tostring(k)) => {
      name                 = try(v.name, tostring(k))
      project_id           = try(v.project_id, local.default_project_id)
      region               = try(v.region, local.default_region)
      database_version     = upper(try(v.database_version, "POSTGRES_15"))
      tier                 = try(v.tier, "db-custom-2-7680")
      availability_type    = upper(try(v.availability_type, "REGIONAL")) # REGIONAL (HA) or ZONAL
      deletion_protection  = try(v.deletion_protection, true)
      disk_size            = try(v.disk_size, 20)
      disk_type            = upper(try(v.disk_type, "PD_SSD"))
      disk_autoresize      = try(v.disk_autoresize, true)
      disk_autoresize_limit= try(v.disk_autoresize_limit, 1000)
      kms_key_name         = try(v.kms_key_name, null)
      private_network = (
        try(v.network, try(v.private_network, local.default_network)) != null && try(v.network, try(v.private_network, local.default_network)) != "" ? (
          startswith(try(v.network, try(v.private_network, local.default_network)), "projects/") ?
          try(v.network, try(v.private_network, local.default_network)) :
          "projects/${try(v.project_id, local.default_project_id)}/global/networks/${try(v.network, try(v.private_network, local.default_network))}"
        ) : null
      )
      allocated_ip_range   = try(v.allocated_ip_range, null)
      ipv4_enabled         = try(v.ipv4_enabled, try(v.enable_public_ip, false))
      authorized_networks  = try(v.authorized_networks, [])
      ssl_mode             = try(v.ssl_mode, (try(v.require_ssl, true) ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"))
      query_insights       = try(v.query_insights, true)
      backup_configuration = {
        enabled                        = try(v.backup_configuration.enabled, true)
        point_in_time_recovery_enabled = try(v.backup_configuration.point_in_time_recovery_enabled, true)
        start_time                     = try(v.backup_configuration.start_time, "02:00")
        transaction_log_retention_days = try(v.backup_configuration.transaction_log_retention_days, 7)
        retained_backups               = try(v.backup_configuration.retained_backups, 14)
      }
      maintenance_window = {
        day          = try(v.maintenance_window.day, 7) # Sunday
        hour         = try(v.maintenance_window.hour, 3)
        update_track = try(v.maintenance_window.update_track, "stable")
      }
      database_flags = try(v.database_flags, {})
      labels         = try(v.labels, {})
      databases      = try(v.databases, [])
      users          = try(v.users, [])
    }
  }

  sql_databases = flatten([
    for inst_key, inst in local.cloud_sql_instances_map : [
      for db in inst.databases : {
        key       = "${inst.name}-${try(db.name, tostring(db))}"
        instance  = inst.name
        project_id= inst.project_id
        name      = try(db.name, tostring(db))
        charset   = try(db.charset, "UTF8")
        collation = try(db.collation, "en_US.UTF8")
      }
    ]
  ])

  sql_databases_map = {
    for item in local.sql_databases : item.key => item
  }

  sql_users = flatten([
    for inst_key, inst in local.cloud_sql_instances_map : [
      for u in inst.users : {
        key       = "${inst.name}-${try(u.name, tostring(u))}"
        instance  = inst.name
        project_id= inst.project_id
        name      = try(u.name, tostring(u))
        password  = try(u.password, null)
        host      = try(u.host, null)
        type      = try(u.type, "BUILT_IN") # BUILT_IN, CLOUD_IAM_USER, CLOUD_IAM_SERVICE_ACCOUNT
      }
    ]
  ])

  sql_users_map = {
    for item in local.sql_users : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 3. AlloyDB for PostgreSQL
  # ----------------------------------------------------------------------------
  raw_alloydb          = try(local.cfg.alloydb, {})
  raw_alloydb_clusters = try(local.raw_alloydb.clusters, {})

  alloydb_clusters_map = {
    for k, v in local.raw_alloydb_clusters : try(v.name, tostring(k)) => {
      cluster_id                       = try(v.name, tostring(k))
      project_id                       = try(v.project_id, local.default_project_id)
      location                         = try(v.location, try(v.region, local.default_region))
      display_name                     = try(v.display_name, "AlloyDB Cluster ${try(v.name, tostring(k))}")
      network = (
        try(v.network, local.default_network) != null && try(v.network, local.default_network) != "" ? (
          startswith(try(v.network, local.default_network), "projects/") ?
          try(v.network, local.default_network) :
          "projects/${try(v.project_id, local.default_project_id)}/global/networks/${try(v.network, local.default_network)}"
        ) : "projects/${try(v.project_id, local.default_project_id)}/global/networks/default"
      )
      allocated_ip_range               = try(v.allocated_ip_range, null)
      initial_user_password            = try(v.initial_user_password, try(v.password, null))
      automated_backup_policy = {
        enabled         = try(v.automated_backup_policy.enabled, true)
        days_of_week    = try(v.automated_backup_policy.days_of_week, try(v.weekly_backup_days, ["SUNDAY"]))
        start_time_hour = try(
          v.automated_backup_policy.start_time_hour,
          try(
            tonumber(split(":", try(v.weekly_backup_time, "02:00"))[0]),
            2
          )
        )
        backup_count    = try(v.automated_backup_policy.backup_count, try(v.backup_count, 14))
      }
      continuous_backup_recovery_window_days = try(
        v.continuous_backup_recovery_window_days,
        try(v.continuous_backup_retention_days, 14)
      )
      kms_key_name                     = try(v.kms_key_name, null)
      deletion_protection              = try(v.deletion_protection, false)
      labels                           = try(v.labels, {})
      primary_instance                 = try(v.primary_instance, {})
      read_pools                       = try(v.read_pools, [])
    }
  }

  alloydb_primary_instances_map = {
    for k, v in local.alloydb_clusters_map : k => {
      cluster_name      = v.cluster_id
      project_id        = v.project_id
      location          = v.location
      instance_id       = try(v.primary_instance.instance_id, "${v.cluster_id}-primary")
      display_name      = try(v.primary_instance.display_name, "Primary Instance for ${v.cluster_id}")
      cpu_count         = try(v.primary_instance.cpu_count, 2)
      availability_type = upper(try(v.primary_instance.availability_type, "REGIONAL"))
      database_flags    = try(v.primary_instance.database_flags, {})
      labels            = try(v.primary_instance.labels, v.labels)
    } if can(v.primary_instance) && length(keys(v.primary_instance)) > 0
  }

  alloydb_read_pools = flatten([
    for c_key, c in local.alloydb_clusters_map : [
      for rp_key, rp in c.read_pools : {
        key          = "${c.cluster_id}-${try(rp.instance_id, tostring(rp_key))}"
        cluster_name = c.cluster_id
        project_id   = c.project_id
        location     = c.location
        instance_id  = try(rp.instance_id, tostring(rp_key))
        display_name = try(rp.display_name, "Read Pool ${rp_key} for ${c.cluster_id}")
        cpu_count    = try(rp.cpu_count, 2)
        node_count   = try(rp.node_count, 1)
        database_flags = try(rp.database_flags, {})
        labels       = try(rp.labels, c.labels)
      }
    ]
  ])

  alloydb_read_pools_map = {
    for item in local.alloydb_read_pools : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 4. Memorystore Redis (In-Memory Cache & Session Store)
  # ----------------------------------------------------------------------------
  raw_redis           = try(local.cfg.memorystore_redis, try(local.cfg.redis, {}))
  raw_redis_instances = try(local.raw_redis.instances, local.raw_redis)

  redis_instances_map = {
    for k, v in local.raw_redis_instances : try(v.name, tostring(k)) => {
      name                    = try(v.name, tostring(k))
      project_id              = try(v.project_id, local.default_project_id)
      region                  = try(v.region, local.default_region)
      tier                    = upper(try(v.tier, "STANDARD_HA")) # STANDARD_HA (Multi-Zone HA) or BASIC
      memory_size_gb          = try(v.memory_size_gb, 1)
      redis_version           = upper(try(v.redis_version, "REDIS_7_0"))
      display_name            = try(v.display_name, "Memorystore Redis ${try(v.name, tostring(k))}")
      authorized_network = (
        try(v.network, try(v.authorized_network, local.default_network)) != null && try(v.network, try(v.authorized_network, local.default_network)) != "" ? (
          startswith(try(v.network, try(v.authorized_network, local.default_network)), "projects/") ?
          try(v.network, try(v.authorized_network, local.default_network)) :
          "projects/${try(v.project_id, local.default_project_id)}/global/networks/${try(v.network, try(v.authorized_network, local.default_network))}"
        ) : "projects/${try(v.project_id, local.default_project_id)}/global/networks/default"
      )
      connect_mode            = upper(try(v.connect_mode, "PRIVATE_SERVICE_ACCESS"))
      reserved_ip_range       = try(v.reserved_ip_range, null)
      auth_enabled            = try(v.auth_enabled, true)
      transit_encryption_mode = upper(try(v.transit_encryption_mode, "SERVER_AUTHENTICATION"))
      rdb_snapshot_period     = upper(try(v.rdb_snapshot_period, "TWELVE_HOURS")) # ONE_HOUR, SIX_HOURS, TWELVE_HOURS, TWENTY_FOUR_HOURS
      labels                  = try(v.labels, {})
    } if can(v.tier) || can(v.memory_size_gb) || can(v.name)
  }

  # ----------------------------------------------------------------------------
  # 5. Firestore (Serverless Document NoSQL)
  # ----------------------------------------------------------------------------
  raw_firestore = try(local.cfg.firestore, {})
  raw_firestore_databases = try(local.raw_firestore.databases, local.raw_firestore)

  firestore_databases_map = {
    for k, v in local.raw_firestore_databases : try(v.name, tostring(k)) => {
      name                             = try(v.name, tostring(k))
      project_id                       = try(v.project_id, local.default_project_id)
      location_id                      = try(v.location_id, try(v.location, local.default_region))
      type                             = upper(try(v.type, "FIRESTORE_NATIVE")) # FIRESTORE_NATIVE or DATASTORE_MODE
      delete_protection_state          = upper(try(v.delete_protection_state, "DELETE_PROTECTION_ENABLED"))
      point_in_time_recovery_enablement= upper(try(v.point_in_time_recovery_enablement, "POINT_IN_TIME_RECOVERY_ENABLED"))
      kms_key_name                     = try(v.kms_key_name, null)
      backup_schedules                 = try(v.backup_schedules, [])
    } if can(v.type) || can(v.location_id) || can(v.location) || can(v.name)
  }

  firestore_backup_schedules = flatten([
    for db_key, db in local.firestore_databases_map : [
      for idx, bs in db.backup_schedules : {
        key            = "${db.name}-backup-${idx}"
        database_name  = db.name
        project_id     = db.project_id
        retention_days = try(bs.retention_days, 14)
        recurrence     = lower(try(bs.recurrence, "daily")) # daily or weekly
        day_of_week    = upper(try(bs.day_of_week, "SUNDAY"))
      }
    ]
  ])

  firestore_backup_schedules_map = {
    for item in local.firestore_backup_schedules : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 6. Cloud Spanner (Global Multi-Region / Regional Highly-Available RDBMS)
  # ----------------------------------------------------------------------------
  raw_spanner           = try(local.cfg.spanner, {})
  raw_spanner_instances = try(local.raw_spanner.instances, local.raw_spanner)

  spanner_instances_map = {
    for k, v in local.raw_spanner_instances : try(v.name, tostring(k)) => {
      name             = try(v.name, tostring(k))
      project_id       = try(v.project_id, local.default_project_id)
      config           = try(v.config, "regional-${try(v.region, local.default_region)}")
      display_name     = try(v.display_name, "Spanner Instance ${try(v.name, tostring(k))}")
      num_nodes        = try(v.autoscaling_config, null) == null && try(v.processing_units, null) == null ? try(v.num_nodes, 1) : null
      processing_units = try(v.autoscaling_config, null) == null && try(v.num_nodes, null) == null ? try(v.processing_units, null) : null
      autoscaling_config = try(v.autoscaling_config, null) != null ? {
        min_processing_units                  = try(v.autoscaling_config.min_processing_units, 100)
        max_processing_units                  = try(v.autoscaling_config.max_processing_units, 1000)
        high_priority_cpu_utilization_percent = try(v.autoscaling_config.high_priority_cpu_utilization_percent, try(v.autoscaling_config.high_priority_cpu_target, 65))
      } : null
      deletion_protection = try(v.deletion_protection, false)
      labels              = try(v.labels, {})
      databases           = try(v.databases, [])
    } if can(v.config) || can(v.name) || can(v.databases)
  }

  spanner_databases = flatten([
    for inst_key, inst in local.spanner_instances_map : [
      for db in inst.databases : {
        key                      = "${inst.name}-${try(db.name, tostring(db))}"
        instance                 = inst.name
        project_id               = inst.project_id
        name                     = try(db.name, tostring(db))
        version_retention_period = try(db.version_retention_period, "7d") # PITR
        ddl                      = try(db.ddl, [])
        deletion_protection      = try(db.deletion_protection, false)
        kms_key_name             = try(db.kms_key_name, null)
        backup_schedules         = try(db.backup_schedules, [])
      }
    ]
  ])

  spanner_databases_map = {
    for item in local.spanner_databases : item.key => item
  }

  spanner_backup_schedules = flatten([
    for db_key, db in local.spanner_databases_map : [
      for bs in db.backup_schedules : {
        key                = "${db.instance}-${db.name}-${try(bs.name, "backup")}"
        name               = try(bs.name, "daily-backup")
        instance           = db.instance
        database           = db.name
        project_id         = db.project_id
        retention_duration = try(bs.retention_duration, "604800s") # 7 days
        cron_spec          = try(bs.cron_spec, "0 2 * * *")
      }
    ]
  ])

  spanner_backup_schedules_map = {
    for item in local.spanner_backup_schedules : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 7. Cloud Bigtable (Low-Latency High-Throughput NoSQL)
  # ----------------------------------------------------------------------------
  raw_bigtable           = try(local.cfg.bigtable, {})
  raw_bigtable_instances = try(local.raw_bigtable.instances, local.raw_bigtable)

  bigtable_instances_map = {
    for k, v in local.raw_bigtable_instances : try(v.name, tostring(k)) => {
      name                = try(v.name, tostring(k))
      project_id          = try(v.project_id, local.default_project_id)
      display_name        = try(v.display_name, "Bigtable Instance ${try(v.name, tostring(k))}")
      deletion_protection = try(v.deletion_protection, false)
      labels              = try(v.labels, {})
      clusters            = try(v.clusters, [
        {
          cluster_id   = "${try(v.name, tostring(k))}-c1"
          zone         = "${try(v.region, local.default_region)}-a"
          num_nodes    = 1
          storage_type = "SSD"
        }
      ])
      tables              = try(v.tables, [])
    } if can(v.clusters) || can(v.tables) || can(v.name)
  }

  bigtable_tables = flatten([
    for inst_key, inst in local.bigtable_instances_map : [
      for tbl in inst.tables : {
        key              = "${inst.name}-${try(tbl.name, tostring(tbl))}"
        instance_name    = inst.name
        project_id       = inst.project_id
        name             = try(tbl.name, tostring(tbl))
        split_keys       = try(tbl.split_keys, [])
        column_families  = try(tbl.column_families, [])
      }
    ]
  ])

  bigtable_tables_map = {
    for item in local.bigtable_tables : item.key => item
  }
}
