# ==============================================================================
# 3. Cloud Data Loss Prevention (Cloud DLP / Sensitive Data Protection)
# ==============================================================================
# Provisions automated sensitive data discovery templates, de-identification
# masking rules, and scheduled inspection triggers across Cloud Storage / BigQuery.
# ==============================================================================

# ------------------------------------------------------------------------------
# DLP Inspection Templates (Detects PII, Secrets, Financial, and Custom InfoTypes)
# ------------------------------------------------------------------------------
resource "google_data_loss_prevention_inspect_template" "inspect_templates" {
  for_each = local.inspect_templates_map

  parent = (
    each.value.location == "global" ?
    "projects/${each.value.project_id}" :
    "projects/${each.value.project_id}/locations/${each.value.location}"
  )

  template_id  = each.value.template_id
  display_name = each.value.display_name
  description  = each.value.description

  inspect_config {
    min_likelihood = each.value.min_likelihood
    include_quote  = each.value.include_quote

    dynamic "info_types" {
      for_each = each.value.info_types
      content {
        name = info_types.value
      }
    }

    limits {
      max_findings_per_item    = each.value.max_findings_per_item
      max_findings_per_request = each.value.max_findings_per_request
    }
  }
}

# ------------------------------------------------------------------------------
# DLP De-identification Templates (Character Masking, Tokenization, Replacement)
# ------------------------------------------------------------------------------
resource "google_data_loss_prevention_deidentify_template" "deidentify_templates" {
  for_each = local.deidentify_templates_map

  parent = (
    each.value.location == "global" ?
    "projects/${each.value.project_id}" :
    "projects/${each.value.project_id}/locations/${each.value.location}"
  )

  template_id  = each.value.template_id
  display_name = each.value.display_name
  description  = each.value.description

  deidentify_config {
    info_type_transformations {
      transformations {
        dynamic "info_types" {
          for_each = each.value.info_types
          content {
            name = info_types.value
          }
        }

        primitive_transformation {
          dynamic "character_mask_config" {
            for_each = each.value.transformation_type == "mask" ? [1] : []
            content {
              masking_character = each.value.mask_character
              number_to_mask    = each.value.number_to_mask
              reverse_order     = each.value.reverse_order
            }
          }

          dynamic "replace_config" {
            for_each = each.value.transformation_type == "replace" ? [1] : []
            content {
              new_value {
                string_value = each.value.replace_value
              }
            }
          }
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# DLP Scheduled Job Triggers (Periodic Storage & BigQuery Inspection)
# ------------------------------------------------------------------------------
resource "google_data_loss_prevention_job_trigger" "triggers" {
  for_each = local.job_triggers_map

  parent = (
    each.value.location == "global" ?
    "projects/${each.value.project_id}" :
    "projects/${each.value.project_id}/locations/${each.value.location}"
  )

  trigger_id   = each.value.trigger_id
  display_name = each.value.display_name
  description  = each.value.description
  status       = each.value.status

  inspect_job {
    inspect_template_name = (
      each.value.inspect_template_name != null ? (
        startswith(each.value.inspect_template_name, "projects/") ?
        each.value.inspect_template_name :
        try(google_data_loss_prevention_inspect_template.inspect_templates[each.value.inspect_template_name].id, each.value.inspect_template_name)
      ) : null
    )

    storage_config {
      dynamic "cloud_storage_options" {
        for_each = each.value.cloud_storage_bucket != null ? [1] : []
        content {
          file_set {
            url = startswith(each.value.cloud_storage_bucket, "gs://") ? "${each.value.cloud_storage_bucket}/*" : "gs://${each.value.cloud_storage_bucket}/*"
          }
        }
      }

      dynamic "big_query_options" {
        for_each = each.value.bigquery_dataset != null && each.value.bigquery_table != null ? [1] : []
        content {
          table_reference {
            project_id = each.value.project_id
            dataset_id = each.value.bigquery_dataset
            table_id   = each.value.bigquery_table
          }
        }
      }
    }

    dynamic "actions" {
      for_each = each.value.pubsub_topic != null ? [1] : []
      content {
        pub_sub {
          topic = each.value.pubsub_topic
        }
      }
    }
  }

  triggers {
    schedule {
      recurrence_period_duration = each.value.recurrence_period_duration
    }
  }

  depends_on = [
    google_data_loss_prevention_inspect_template.inspect_templates
  ]
}
