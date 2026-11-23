# ==============================================================================
# Google Cloud AlloyDB for PostgreSQL Clusters, Primary & Read Pool Instances
# ==============================================================================

resource "google_alloydb_cluster" "clusters" {
  for_each = local.alloydb_clusters_map

  cluster_id   = each.value.cluster_id
  project      = each.value.project_id
  location     = each.value.location
  display_name = each.value.display_name
  labels       = each.value.labels

  network_config {
    network            = each.value.network
    allocated_ip_range = each.value.allocated_ip_range
  }

  dynamic "initial_user" {
    for_each = each.value.initial_user_password != null ? [1] : []
    content {
      password = each.value.initial_user_password
    }
  }

  automated_backup_policy {
    enabled = each.value.automated_backup_policy.enabled

    weekly_schedule {
      days_of_week = each.value.automated_backup_policy.days_of_week
      start_times {
        hours   = each.value.automated_backup_policy.start_time_hour
        minutes = 0
      }
    }

    quantity_based_retention {
      count = each.value.automated_backup_policy.backup_count
    }
  }

  continuous_backup_config {
    enabled              = true
    recovery_window_days = each.value.continuous_backup_recovery_window_days
  }

  dynamic "encryption_config" {
    for_each = each.value.kms_key_name != null ? [1] : []
    content {
      kms_key_name = each.value.kms_key_name
    }
  }
}

resource "google_alloydb_instance" "primary_instances" {
  for_each = local.alloydb_primary_instances_map

  cluster       = google_alloydb_cluster.clusters[each.value.cluster_name].name
  instance_id   = each.value.instance_id
  instance_type = "PRIMARY"
  display_name  = each.value.display_name
  labels        = each.value.labels

  machine_config {
    cpu_count = each.value.cpu_count
  }

  availability_type = each.value.availability_type
  database_flags    = each.value.database_flags

  depends_on = [
    google_alloydb_cluster.clusters
  ]
}

resource "google_alloydb_instance" "read_pools" {
  for_each = local.alloydb_read_pools_map

  cluster       = google_alloydb_cluster.clusters[each.value.cluster_name].name
  instance_id   = each.value.instance_id
  instance_type = "READ_POOL"
  display_name  = each.value.display_name
  labels        = each.value.labels

  machine_config {
    cpu_count = each.value.cpu_count
  }

  read_pool_config {
    node_count = each.value.node_count
  }

  database_flags = each.value.database_flags

  depends_on = [
    google_alloydb_instance.primary_instances
  ]
}

resource "google_alloydb_user" "users" {
  for_each = local.alloydb_users_map

  cluster        = google_alloydb_cluster.clusters[each.value.cluster_name].name
  user_id        = each.value.user_id
  user_type      = each.value.user_type
  password       = each.value.password
  database_roles = each.value.database_roles

  depends_on = [
    google_alloydb_instance.primary_instances
  ]
}
