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
# Firestore / Datastore Databases (Serverless Resilient NoSQL)
# ------------------------------------------------------------------------------

resource "google_firestore_database" "databases" {
  for_each = local.firestore_databases_map

  name                              = each.value.name
  project                           = each.value.project_id
  location_id                       = each.value.location_id
  type                              = each.value.type
  delete_protection_state           = each.value.delete_protection_state
  point_in_time_recovery_enablement = each.value.point_in_time_recovery_enablement

  dynamic "cmek_config" {
    for_each = each.value.kms_key_name != null ? [1] : []
    content {
      kms_key_name = each.value.kms_key_name
    }
  }
}

# ------------------------------------------------------------------------------
# Firestore Automated Backup Schedules
# ------------------------------------------------------------------------------

resource "google_firestore_backup_schedule" "backup_schedules" {
  for_each = local.firestore_backup_schedules_map

  project   = each.value.project_id
  database  = google_firestore_database.databases[each.value.database_name].name
  retention = "${each.value.retention_days * 86400}s"

  dynamic "daily_recurrence" {
    for_each = each.value.recurrence == "daily" ? [1] : []
    content {}
  }

  dynamic "weekly_recurrence" {
    for_each = each.value.recurrence == "weekly" ? [1] : []
    content {
      day = each.value.day_of_week
    }
  }
}

# ------------------------------------------------------------------------------
# Firestore Composite Indexes
# ------------------------------------------------------------------------------

resource "google_firestore_index" "indexes" {
  for_each = local.firestore_indexes_map

  project     = each.value.project_id
  database    = google_firestore_database.databases[each.value.database_name].name
  collection  = each.value.collection
  query_scope = each.value.query_scope

  dynamic "fields" {
    for_each = each.value.fields
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }

  depends_on = [
    google_firestore_database.databases
  ]
}
