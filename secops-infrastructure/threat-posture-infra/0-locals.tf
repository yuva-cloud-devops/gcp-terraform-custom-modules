# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the YAML configuration and flattens Security Command Center (SCC)
# notification configs, BigQuery continuous finding exports, and Cloud Asset
# Inventory real-time drift feeds.
# Supports both map-based (idiomatic key-value) and list-based YAML structures.
# ==============================================================================

locals {
  # ----------------------------------------------------------------------------
  # Raw Configuration Input (File Path or Raw Content)
  # ----------------------------------------------------------------------------
  raw_config = yamldecode(
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? file(var.config_file_path) : "{}"
    )
  )

  # Support optional wrapper root key "threat_posture" or "threat_posture_infra"
  raw_root = try(local.raw_config.threat_posture, try(local.raw_config.threat_posture_infra, local.raw_config))

  # Top-level global defaults
  default_project_id = try(local.raw_root.project_id, null)
  default_location   = try(local.raw_root.location, "global")
  organization_id    = try(local.raw_root.organization_id, null)
  common_labels      = try(local.raw_root.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Security Command Center (SCC) Finding Notifications
  # ----------------------------------------------------------------------------
  raw_scc_notif_input = try(
    local.raw_root.scc_notifications,
    try(
      local.raw_root.notifications,
      try(local.raw_root.scc_alerts, {})
    )
  )

  scc_notifications_map = {
    for k, v in local.raw_scc_notif_input : try(v.config_id, try(v.name, tostring(k))) => {
      config_id    = try(v.config_id, try(v.name, tostring(k)))
      project_id   = try(v.project_id, local.default_project_id)
      location     = try(v.location, local.default_location)
      description  = try(v.description, "Managed Security Command Center Finding Notification")
      topic_name   = try(v.pubsub_topic, try(v.topic, "${try(v.config_id, tostring(k))}-topic"))
      create_topic = try(v.create_topic, true)
      filter       = try(v.filter, "state=\"ACTIVE\" AND (severity=\"HIGH\" OR severity=\"CRITICAL\")")
    }
  }

  # ----------------------------------------------------------------------------
  # 2. Security Command Center (SCC) BigQuery Continuous Finding Exports
  # ----------------------------------------------------------------------------
  raw_scc_bq_input = try(
    local.raw_root.scc_bigquery_exports,
    try(
      local.raw_root.bigquery_exports,
      try(local.raw_root.scc_exports, {})
    )
  )

  scc_bigquery_exports_map = {
    for k, v in local.raw_scc_bq_input : try(v.export_id, try(v.name, tostring(k))) => {
      export_id        = try(v.export_id, try(v.name, tostring(k)))
      project_id       = try(v.project_id, local.default_project_id)
      location         = try(v.location, local.default_location)
      description      = try(v.description, "Managed SCC v2 Continuous BigQuery Finding Export")
      dataset_id       = try(v.dataset_id, try(v.dataset, "${replace(try(v.export_id, tostring(k)), "-", "_")}_ds"))
      create_dataset   = try(v.create_dataset, true)
      dataset_location = try(v.dataset_location, "US")
      filter           = try(v.filter, "state=\"ACTIVE\"")
    }
  }

  # ----------------------------------------------------------------------------
  # 3. Cloud Asset Inventory (CAI) Real-Time Drift Feeds
  # ----------------------------------------------------------------------------
  raw_asset_feeds_input = try(
    local.raw_root.asset_feeds,
    try(
      local.raw_root.cloud_asset_feeds,
      try(local.raw_root.feeds, {})
    )
  )

  asset_feeds_map = {
    for k, v in local.raw_asset_feeds_input : try(v.feed_id, try(v.name, tostring(k))) => {
      feed_id      = try(v.feed_id, try(v.name, tostring(k)))
      project_id   = try(v.project_id, local.default_project_id)
      description  = try(v.description, "Managed Cloud Asset Inventory real-time change feed")
      content_type = upper(try(v.content_type, "RESOURCE")) # RESOURCE, IAM_POLICY, ACCESS_POLICY, OS_INVENTORY, RELATIONSHIP
      asset_types  = try(v.asset_types, [])
      topic_name   = try(v.pubsub_topic, try(v.topic, "${try(v.feed_id, tostring(k))}-topic"))
      create_topic = try(v.create_topic, true)
      condition    = try(v.condition, null)
    }
  }

  # ----------------------------------------------------------------------------
  # Consolidated Pub/Sub Topics to Provision
  # ----------------------------------------------------------------------------
  # Collects all required Pub/Sub topics across SCC notifications and Asset feeds
  scc_topics = {
    for k, v in local.scc_notifications_map : "scc-${k}" => {
      name       = v.topic_name
      project_id = v.project_id
      purpose    = "scc"
    } if v.create_topic && !startswith(v.topic_name, "projects/")
  }

  asset_topics = {
    for k, v in local.asset_feeds_map : "asset-${k}" => {
      name       = v.topic_name
      project_id = v.project_id
      purpose    = "asset"
    } if v.create_topic && !startswith(v.topic_name, "projects/")
  }

  managed_topics_map = merge(local.scc_topics, local.asset_topics)
}

# ------------------------------------------------------------------------------
# Project Metadata Resolution (Project Number for Google-Managed Service Accounts)
# ------------------------------------------------------------------------------
data "google_project" "project" {
  project_id = local.default_project_id
}
