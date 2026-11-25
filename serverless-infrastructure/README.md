# GCP Serverless Infrastructure Terraform Custom Module

This production-ready, declarative Terraform module provisions and manages **Google Cloud Serverless Infrastructure** using Google Cloud's modern standards (2024+):
* **Cloud Run Services (v2)**: Microservices, webhooks, and HTTP APIs with traffic splitting and concurrency controls.
* **Cloud Run Jobs (v2)**: Batch run-to-completion tasks, database migrations, and ETL scripts.
* **Cloud Functions (2nd Gen)**: Event-driven functions powered by Cloud Run.
* **Direct VPC Egress (2024+ Standard)**: Attaches serverless containers directly to your VPC subnet IPs with **zero connector VM costs** and up to **100 Gbps** throughput.
* **Internal vs. External Controls**: Declarative toggles for public internet-facing vs. internal-only private services.
* **Eventarc & Cloud Workflows**: Event routers and serverless state machine workflows.
* **Cloud Tasks & Cloud Scheduler**: Rate-limited asynchronous queues and cron jobs.

---

## Architecture: Direct VPC Egress vs. Legacy Connectors

```
┌────────────────────────────────────────────────────────┐
│ Modern Recommended (2024+): Direct VPC Egress          │
│  Cloud Run / Cloud Functions (2nd gen)                 │
│         │                                              │
│         ▼ (Subnet IP directly allocated)               │
│  [ testing-environment-private-subnet-mumbai ]         │
│  • Zero extra cost (No connector VMs to pay for)       │
│  • Up to 100 Gbps throughput, sub-millisecond latency  │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│ Legacy Method: Serverless VPC Access Connector         │
│  Requires dedicated /28 subnet and running e2-micro VMs│
│  • Additional hourly VM cost (~$18–$35/month minimum)  │
│  • Scaling delays during traffic spikes                │
└────────────────────────────────────────────────────────┘
```

### Direct VPC Egress Modes
* **`PRIVATE_RANGES_ONLY` (Default & Recommended)**: Only internal RFC 1918 traffic (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) routes through the VPC subnet (e.g. to reach private Cloud SQL or Redis). Public internet requests route directly over Google's high-speed public backbone.
* **`ALL_TRAFFIC`**: All outbound traffic (including external internet) routes through the VPC subnet. Use this when outbound calls must egress through a **Cloud NAT with a reserved static IP** for third-party IP whitelisting.

---

## Internal vs. External Matrix

| Component | **External (Public)** Option | **Internal (Private)** Option |
| :--- | :--- | :--- |
| **Cloud Run Services** | • `ingress: "INGRESS_TRAFFIC_ALL"`<br>• `allow_unauthenticated: true` (`allUsers`) | • `ingress: "INGRESS_TRAFFIC_INTERNAL_ONLY"` or `"INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"`<br>• `allow_unauthenticated: false`<br>• `invoker_members: ["serviceAccount:..."]` |
| **Cloud Run Jobs** | • Pure standalone batch task | • `direct_vpc_egress: enabled: true`<br>• Directly accesses private databases in the VPC |
| **Cloud Functions (2nd Gen)** | • `ingress: "ALLOW_ALL"`<br>• `allow_unauthenticated: true` | • `ingress: "ALLOW_INTERNAL_ONLY"` or `"ALLOW_INTERNAL_AND_GCLB"`<br>• `allow_unauthenticated: false` |
| **Cloud Workflows** | • Orchestrates public SaaS & APIs | • Calls private internal Cloud Run services via authenticated OIDC tokens |
| **Cloud Tasks & Scheduler** | • Dispatches to public URLs | • Dispatches to internal Cloud Run services with OIDC token authentication |

---

## Module Usage

```hcl
module "serverless_infrastructure" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//serverless-infrastructure?ref=main"
  config_file_path = "${path.module}/serverless-infrastructure.yaml"
}
```

---

## Full YAML Schema Specification

```yaml
serverless_infrastructure:
  project_id: "yuvaraj-internal-project"
  region: "asia-south1"
  network: "projects/yuvaraj-internal-project/global/networks/testing-environment-vpc"
  subnetwork: "projects/yuvaraj-internal-project/regions/asia-south1/subnetworks/testing-environment-private-subnet-mumbai"
  tags:
    environment: "dev"
    managed-by: "terraform"

  vpc_access:
    egress_mode: "PRIVATE_RANGES_ONLY" # PRIVATE_RANGES_ONLY or ALL_TRAFFIC

  # ============================================================================
  # 1. Cloud Run Services (v2 API)
  # ============================================================================
  cloud_run_services:
    # Public Webhook / External API
    public-api:
      image: "asia-south1-docker.pkg.dev/yuvaraj-internal-project/app-docker-repo/nginx:v1.0"
      port: 80
      ingress: "INGRESS_TRAFFIC_ALL"
      allow_unauthenticated: true
      concurrency: 80
      scaling:
        min_instances: 0
        max_instances: 5
      resources:
        limits:
          cpu: "1"
          memory: "512Mi"
      direct_vpc_egress:
        enabled: false

    # Internal Microservice (Private Database Access via Direct VPC Egress)
    internal-order-service:
      image: "asia-south1-docker.pkg.dev/yuvaraj-internal-project/app-docker-repo/nginx:v1.0"
      port: 80
      ingress: "INGRESS_TRAFFIC_INTERNAL_ONLY"
      allow_unauthenticated: false
      invoker_members:
        - "serviceAccount:frontend-sa@yuvaraj-internal-project.iam.gserviceaccount.com"
      scaling:
        min_instances: 1
        max_instances: 10
      direct_vpc_egress:
        enabled: true
        egress_mode: "PRIVATE_RANGES_ONLY"
        network_tags:
          - "serverless-backend"

  # ============================================================================
  # 2. Cloud Run Jobs (v2 API)
  # ============================================================================
  cloud_run_jobs:
    db-migration-job:
      image: "asia-south1-docker.pkg.dev/yuvaraj-internal-project/app-docker-repo/nginx:v1.0"
      task_count: 1
      parallelism: 1
      max_retries: 2
      timeout: "900s"
      direct_vpc_egress:
        enabled: true
        egress_mode: "PRIVATE_RANGES_ONLY"

  # ============================================================================
  # 3. Cloud Functions (2nd Gen API)
  # ============================================================================
  cloud_functions:
    order-event-handler:
      runtime: "nodejs20"
      entry_point: "processOrder"
      source_archive_bucket: "yuvaraj-functions-code-bucket"
      source_archive_object: "functions/order-handler.zip"
      ingress: "ALLOW_INTERNAL_ONLY"
      allow_unauthenticated: false
      direct_vpc_egress:
        enabled: true
        egress_mode: "VPC_EGRESS_PRIVATE_RANGES_ONLY"

  # ============================================================================
  # 4. Async Queues & Scheduler
  # ============================================================================
  cloud_tasks_queues:
    order-processing-queue:
      max_dispatches_per_second: 50
      max_concurrent_dispatches: 10

  cloud_scheduler_jobs:
    nightly-db-cleanup:
      schedule: "0 2 * * *"
      time_zone: "Asia/Kolkata"
      http_target:
        uri: "https://internal-order-service-xyz.a.run.app/cleanup"
        http_method: "POST"
        oidc_token:
          service_account_email: "scheduler-runner@yuvaraj-internal-project.iam.gserviceaccount.com"

  # ============================================================================
  # 5. Event Orchestration (Eventarc & Cloud Workflows)
  # ============================================================================
  cloud_workflows:
    order-fulfillment-workflow:
      description: "Coordinates multi-step internal and external order processing"
      source_contents: |
        main:
          steps:
            - init:
                assign:
                  - status: "STARTED"
            - return_status:
                return: ${status}
```
