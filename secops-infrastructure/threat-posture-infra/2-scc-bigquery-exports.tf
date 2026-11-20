# ==============================================================================
# 2. Security Command Center (SCC) BigQuery Continuous Finding Exports
# ==============================================================================
# Provisions continuous data streaming of SCC security findings to BigQuery
# datasets for long-term audit compliance, historical trend analysis, and SIEM/SOC
# security analytics.
# ==============================================================================

# ------------------------------------------------------------------------------
# BigQuery Datasets for SCC Finding Storage
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "scc_datasets" {
  for_each = {
    for k, v in local.scc_bigquery_exports_map : k => v
    if v.create_dataset && !startswith(v.dataset_id, "projects/")
  }

  dataset_id                 = each.value.dataset_id
  project                    = each.value.project_id
  location                   = each.value.dataset_location
  friendly_name              = "SCC Findings Data Lake (${each.key})"
  description                = "Continuous export dataset for Security Command Center v2 findings"
  delete_contents_on_destroy = true
  labels                     = local.common_labels
}

# ------------------------------------------------------------------------------
# IAM Delegation: Allow SCC Service Account to Write Findings to BigQuery Dataset
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset_iam_member" "scc_bq_editor" {
  for_each = {
    for k, v in local.scc_bigquery_exports_map : k => v
    if v.create_dataset && !startswith(v.dataset_id, "projects/")
  }

  project    = each.value.project_id
  dataset_id = google_bigquery_dataset.scc_datasets[each.key].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-scc-notification.iam.gserviceaccount.com"
}

# ------------------------------------------------------------------------------
# SCC v2 Project BigQuery Export Configurations
# ------------------------------------------------------------------------------
resource "google_scc_v2_project_scc_big_query_export" "exports" {
  for_each = local.scc_bigquery_exports_map

  project             = each.value.project_id
  location            = each.value.location
  big_query_export_id = each.value.export_id
  description         = each.value.description

  dataset = (
    startswith(each.value.dataset_id, "projects/") ?
    each.value.dataset_id :
    google_bigquery_dataset.scc_datasets[each.key].id
  )

  filter = each.value.filter

  depends_on = [
    google_bigquery_dataset_iam_member.scc_bq_editor
  ]
}
