# ==============================================================================
# Cloud SQL Instances (PostgreSQL / MySQL / SQL Server), Databases & Users
# ==============================================================================

resource "google_sql_database_instance" "instances" {
  for_each = local.cloud_sql_instances_map

  name                = each.value.name
  project             = each.value.project_id
  region              = each.value.region
  database_version    = each.value.database_version
  deletion_protection = each.value.deletion_protection
  encryption_key_name = each.value.kms_key_name

  settings {
    tier                  = each.value.tier
    availability_type     = each.value.availability_type
    disk_size             = each.value.disk_size
    disk_type             = each.value.disk_type
    disk_autoresize       = each.value.disk_autoresize
    disk_autoresize_limit = each.value.disk_autoresize_limit
    user_labels           = each.value.labels

    ip_configuration {
      ipv4_enabled       = each.value.ipv4_enabled
      private_network    = each.value.private_network
      allocated_ip_range = each.value.allocated_ip_range
      ssl_mode           = each.value.ssl_mode

      dynamic "authorized_networks" {
        for_each = each.value.authorized_networks
        content {
          name  = try(authorized_networks.value.name, authorized_networks.key)
          value = try(authorized_networks.value.value, tostring(authorized_networks.value))
        }
      }
    }

    backup_configuration {
      enabled                        = each.value.backup_configuration.enabled
      point_in_time_recovery_enabled = each.value.backup_configuration.point_in_time_recovery_enabled
      start_time                     = each.value.backup_configuration.start_time
      transaction_log_retention_days = each.value.backup_configuration.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = each.value.backup_configuration.retained_backups
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = each.value.maintenance_window.day
      hour         = each.value.maintenance_window.hour
      update_track = each.value.maintenance_window.update_track
    }

    dynamic "insights_config" {
      for_each = each.value.query_insights ? [1] : []
      content {
        query_insights_enabled  = true
        query_string_length     = 1024
        record_application_tags = true
        record_client_address   = true
      }
    }

    dynamic "database_flags" {
      for_each = each.value.database_flags
      content {
        name  = database_flags.key
        value = tostring(database_flags.value)
      }
    }
  }
}

resource "google_sql_database" "databases" {
  for_each = local.sql_databases_map

  name      = each.value.name
  instance  = try(google_sql_database_instance.instances[each.value.instance].name, each.value.instance)
  project   = each.value.project_id
  charset   = each.value.charset
  collation = each.value.collation

  depends_on = [
    google_sql_database_instance.instances
  ]
}

resource "google_sql_user" "users" {
  for_each = local.sql_users_map

  name     = each.value.name
  instance = try(google_sql_database_instance.instances[each.value.instance].name, each.value.instance)
  project  = each.value.project_id
  password = each.value.password
  host     = each.value.host
  type     = each.value.type

  depends_on = [
    google_sql_database_instance.instances
  ]
}
