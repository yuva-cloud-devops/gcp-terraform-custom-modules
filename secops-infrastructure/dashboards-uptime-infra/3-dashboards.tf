# ==============================================================================
# 3. Cloud Monitoring Operational Dashboards
# ==============================================================================
# Provisions production-ready Cloud Monitoring Dashboards (SecOps Threat Overview,
# Serverless Service Health, and Network Perimeter Status) alongside user-defined
# custom dashboards.
# ==============================================================================

# ------------------------------------------------------------------------------
# 3A. Pre-Packaged SecOps Threat & Audit Compliance Dashboard
# ------------------------------------------------------------------------------
resource "google_monitoring_dashboard" "secops_dashboard" {
  count          = local.enable_secops_dashboard && local.default_project_id != null ? 1 : 0
  project        = local.default_project_id
  dashboard_json = jsonencode({
    displayName = "SecOps & Audit Compliance Overview"
    gridLayout = {
      columns = "2"
      widgets = [
        {
          title = "CIS 2.4 - IAM Policy & Role Modifications"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/cis_iam_policy_changes\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "CIS 2.7 - VPC Firewall Rule Modifications"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/cis_firewall_rule_changes\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "CIS 2.10 - Storage Bucket IAM Changes"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/cis_storage_iam_changes\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "CIS 2.12 - Cloud KMS Key Destruction Events"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/cis_kms_key_destruction\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        }
      ]
    }
  })
}

# ------------------------------------------------------------------------------
# 3B. Pre-Packaged Serverless Service Operations Dashboard
# ------------------------------------------------------------------------------
resource "google_monitoring_dashboard" "serverless_dashboard" {
  count          = local.enable_serverless_dashboard && local.default_project_id != null ? 1 : 0
  project        = local.default_project_id
  dashboard_json = jsonencode({
    displayName = "Serverless Infrastructure & Service Health"
    gridLayout = {
      columns = "2"
      widgets = [
        {
          title = "Cloud Run Request Count by Response Code Class"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["metric.label.response_code_class"]
                  }
                }
              }
              plotType = "STACKED_BAR"
            }]
          }
        },
        {
          title = "Cloud Run Request Latency (p95)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_PERCENTILE_95"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "Cloud Run Container Instance Count"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/instance_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["metric.label.state"]
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "Cloud Tasks Queue Backlog (Task Count)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_tasks_queue\" AND metric.type=\"cloudtasks.googleapis.com/queue/task_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.queue_id"]
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        }
      ]
    }
  })
}

# ------------------------------------------------------------------------------
# 3C. Pre-Packaged Network & Perimeter Health Dashboard
# ------------------------------------------------------------------------------
resource "google_monitoring_dashboard" "network_dashboard" {
  count          = local.enable_network_dashboard && local.default_project_id != null ? 1 : 0
  project        = local.default_project_id
  dashboard_json = jsonencode({
    displayName = "Network & Perimeter Infrastructure Health"
    gridLayout = {
      columns = "2"
      widgets = [
        {
          title = "Cloud NAT Translation Errors & Drops"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"nat_gateway\" AND metric.type=\"router.googleapis.com/nat/error_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["metric.label.error_type"]
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        },
        {
          title = "HA VPN Tunnel Sent & Received Bytes"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"vpn_gateway\" AND metric.type=\"vpn.googleapis.com/network/sent_bytes_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["metric.label.tunnel_id"]
                  }
                }
              }
              plotType = "LINE"
            }]
          }
        }
      ]
    }
  })
}

# ------------------------------------------------------------------------------
# 3D. Custom User-Defined Dashboards
# ------------------------------------------------------------------------------
resource "google_monitoring_dashboard" "custom_dashboards" {
  for_each = local.custom_dashboards

  project        = each.value.project_id
  dashboard_json = each.value.dashboard_json
}
