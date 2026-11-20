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
# Cloud Spanner Instances (Global Multi-Region / Regional 99.999% SLA RDBMS)
# ------------------------------------------------------------------------------

resource "google_spanner_instance" "instances" {
  for_each = local.spanner_instances_map

  name             = each.value.name
  config           = each.value.config
  display_name     = each.value.display_name
  project          = each.value.project_id
  num_nodes        = each.value.num_nodes
  processing_units = each.value.processing_units

  dynamic "autoscaling_config" {
    for_each = each.value.autoscaling_config != null ? [each.value.autoscaling_config] : []
    content {
      autoscaling_limits {
        min_processing_units = autoscaling_config.value.min_processing_units
        max_processing_units = autoscaling_config.value.max_processing_units
      }
      autoscaling_targets {
        high_priority_cpu_utilization_percent = autoscaling_config.value.high_priority_cpu_utilization_percent
      }
    }
  }

  labels = each.value.labels
}

# ------------------------------------------------------------------------------
# Cloud Spanner Logical Databases (PITR & DDL Schemas)
# ------------------------------------------------------------------------------

resource "google_spanner_database" "databases" {
  for_each = local.spanner_databases_map

  instance                 = try(google_spanner_instance.instances[each.value.instance].name, each.value.instance)
  name                     = each.value.name
  project                  = each.value.project_id
  version_retention_period = each.value.version_retention_period
  ddl                      = each.value.ddl
  deletion_protection      = each.value.deletion_protection

  dynamic "encryption_config" {
    for_each = each.value.kms_key_name != null ? [1] : []
    content {
      kms_key_name = each.value.kms_key_name
    }
  }

  depends_on = [
    google_spanner_instance.instances
  ]
}

# ------------------------------------------------------------------------------
# Cloud Spanner Automated Backup Schedules
# ------------------------------------------------------------------------------

resource "google_spanner_backup_schedule" "backup_schedules" {
  for_each = local.spanner_backup_schedules_map

  instance           = try(google_spanner_instance.instances[each.value.instance].name, each.value.instance)
  database           = try(google_spanner_database.databases["${each.value.instance}-${each.value.database}"].name, each.value.database)
  name               = each.value.name
  retention_duration = each.value.retention_duration

  spec {
    cron_spec {
      text = each.value.cron_spec
    }
  }

  full_backup_spec {}

  depends_on = [
    google_spanner_database.databases
  ]
}
