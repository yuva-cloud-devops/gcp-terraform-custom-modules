# GCP Monitoring & Alerting Infrastructure Terraform Module (`monitoring-alerting-infra`)

Enterprise-grade, **YAML-driven** Terraform module for automated provisioning and orchestration of **Multi-Project Cloud Monitoring Metric Scopes, Notification Channels, CIS GCP Foundations Benchmark v3 Security Alerts, and Infrastructure Metric Threshold Policies**.

---

## 🏛️ Architecture Overview

```mermaid
flowchart TD
    subgraph MultiProject["Multi-Project Metric Scoping"]
        SP["Scoping Project<br/>(Single Pane of Glass)"]
        MP1["Service Project A<br/>(GKE / Cloud Run)"]
        MP2["Service Project B<br/>(Databases / Storage)"]
        MP1 -->|Linked Metric Scope| SP
        MP2 -->|Linked Metric Scope| SP
    end

    subgraph Alerts["Automated Incident Detection"]
        CIS["CIS v3 Security Alerts<br/>(Controls 2.4 - 2.12)"]
        OPS["Operational Threshold Alerts<br/>(Error Rates, CPU, Memory)"]
        LOG["Log-Match Alert Policies<br/>(Specific Audit Events)"]
        SP --> CIS
        SP --> OPS
        SP --> LOG
    end

    subgraph Notifications["Multi-Channel Incident Dispatch"]
        NC1["Slack Channel"]
        NC2["PagerDuty Escalation"]
        NC3["SecOps Email Group"]
        NC4["SIEM Webhook / Pub/Sub"]
        CIS --> NC1
        CIS --> NC2
        OPS --> NC3
        LOG --> NC4
    end
```

---

## 🎯 Key Capabilities

1. **Multi-Project Metric Scopes**:
   - Centrally links multiple remote workload or service projects into a single primary monitoring scoping project (`google_monitoring_monitored_project`).
2. **Notification Channel Orchestration**:
   - Declaratively provisions channels (`email`, `slack`, `pagerduty`, `webhook`, `pubsub`, `sms`) with encrypted sensitive tokens (`auth_token`, `service_key`).
3. **CIS GCP Foundations Benchmark v3 Security Alerts**:
   - Directly links to the 9 CIS Section 2 log metrics provisioned by `audit-compliance-infra`:
     - **CIS 2.4**: IAM Policy & Organization Policy changes (`cis_iam_policy_changes`).
     - **CIS 2.5**: Audit logging config modifications (`cis_audit_config_changes`).
     - **CIS 2.6**: Custom IAM role changes (`cis_custom_role_changes`).
     - **CIS 2.7**: VPC firewall rule modifications (`cis_firewall_rule_changes`).
     - **CIS 2.8**: VPC route modifications (`cis_network_route_changes`).
     - **CIS 2.9**: VPC network or subnet topology changes (`cis_vpc_network_changes`).
     - **CIS 2.10**: Cloud Storage bucket IAM changes (`cis_storage_iam_changes`).
     - **CIS 2.11**: Cloud SQL database configuration updates (`cis_cloud_sql_changes`).
     - **CIS 2.12**: Cloud KMS CryptoKey version destruction (`cis_kms_key_destruction`).
4. **Flexible Operational Alert Policies**:
   - Supports metric threshold conditions, log match conditions, absent metric checks (heartbeats), and MQL queries.

---

## 📋 YAML Configuration Schema

```yaml
project_id: "secops-monitoring-project"

# 1. Multi-Project Metric Scoping
metric_scopes:
  scoping_project: "secops-monitoring-project"
  monitored_projects:
    - "workload-app-prod"
    - "workload-db-prod"
    - "network-host-prod"

# 2. Notification Channels
notification_channels:
  - name: "secops-critical-slack"
    type: "slack"
    display_name: "SecOps #incidents-critical"
    labels:
      channel_name: "#secops-critical"
    sensitive_labels:
      auth_token: "xoxb-your-slack-bot-token"

  - name: "sre-pagerduty"
    type: "pagerduty"
    display_name: "SRE PagerDuty Service"
    sensitive_labels:
      service_key: "your-pagerduty-service-key"

  - name: "cloud-ops-email"
    type: "email"
    display_name: "Cloud Platform Ops Team"
    labels:
      email_address: "cloud-ops@example.com"

# 3. CIS GCP Benchmark v3 Alerts
cis_security_alerts:
  enable: true
  auto_close: "604800s" # 7 days
  notification_channels:
    - "secops-critical-slack"
    - "cloud-ops-email"

# 4. Custom Metric Threshold & Log Match Alerts
alert_policies:
  - name: "cloudrun-high-5xx-error-rate"
    display_name: "Cloud Run High 5xx Error Rate (>5% over 5m)"
    severity: "CRITICAL"
    notification_channels:
      - "sre-pagerduty"
    conditions:
      - type: "threshold"
        display_name: "Cloud Run 5xx response ratio"
        filter: 'metric.type="run.googleapis.com/request_count" AND resource.type="cloud_run_revision" AND metric.label.response_code_class="5xx"'
        comparison: "COMPARISON_GT"
        threshold_value: 10
        duration: "300s"
        alignment_period: "60s"
        per_series_aligner: "ALIGN_RATE"
        cross_series_reducer: "REDUCE_SUM"
```

---

## 🚀 Usage Example

```hcl
module "monitoring_alerting" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//secops-infrastructure/monitoring-alerting-infra?ref=main"
  config_file_path = "${path.module}/monitoring-config.yaml"
}
```
