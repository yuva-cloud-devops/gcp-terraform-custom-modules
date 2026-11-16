# Private Service Connect (PSC) Architecture Example

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Declarative YAML](https://img.shields.io/badge/Config-Declarative%20YAML-orange.svg)](#declarative-configuration-walkthrough)
[![Enterprise Ready](https://img.shields.io/badge/Architecture-Private%20Service%20Connect-success.svg)](#architecture-topology)

This example demonstrates how to implement an enterprise **Private Service Connect (PSC)** deployment using the declarative [private-service-connect](file:///d:/GCP-DevOps-WorkSpace/gcp-terraform-custom-modules/networking-infrastructure/private-service-connect) custom module.

The deployment provisions a consumer VPC network with a dedicated subnet and orchestrates both PSC endpoint flavors defined in [psc.yaml](file:///d:/GCP-DevOps-WorkSpace/gcp-terraform-custom-modules/examples/network/psc-setup/psc.yaml):
1. **Google Cloud APIs (Global Endpoint):** Consuming all Google APIs (`all-apis`) via a private internal IP (`10.20.0.100`) without public internet routability or NAT gateways.
2. **Published SaaS / Producer Services (Regional Endpoints):** Connecting to third-party SaaS services (e.g., Snowflake, MongoDB Atlas) or cross-VPC microservices via regional Service Attachments in `asia-south1`.

---

## Table of Contents

- [Architecture Topology](#architecture-topology)
- [Directory Structure](#directory-structure)
- [Prerequisites & Permissions](#prerequisites--permissions)
- [Declarative Configuration Walkthrough](#declarative-configuration-walkthrough)
  - [1. PSC for Google APIs (Global)](#1-psc-for-google-apis-global)
  - [2. PSC for Service Attachments (Regional SaaS)](#2-psc-for-service-attachments-regional-saas)
- [Deployment Workflow](#deployment-workflow)
  - [Step 1: Authenticate to GCP](#step-1-authenticate-to-gcp)
  - [Step 2: Configure Project & Service Targets](#step-2-configure-project--service-targets)
  - [Step 3: Initialize Terraform](#step-3-initialize-terraform)
  - [Step 4: Plan Deployment](#step-4-plan-deployment)
  - [Step 5: Apply Configuration](#step-5-apply-configuration)
- [Module Outputs](#module-outputs)
- [Verification & Operational Testing](#verification--operational-testing)
- [Architectural Comparison: PSC vs VPC Peering](#architectural-comparison-psc-vs-vpc-peering)
- [Troubleshooting](#troubleshooting)

---

## Architecture Topology

```mermaid
flowchart TD
    subgraph CONSUMER["Consumer VPC: psc-demo-vpc"]
        subgraph SUBNET["Subnet: psc-demo-subnet (10.20.1.0/24 in asia-south1)"]
            VM["Workload VM / GKE Pod<br/>(10.20.1.10)"]
            
            EP_SNOW["PSC Endpoint: psc-snowflake-prod<br/>Static IP: 10.20.1.105"]
            EP_MONGO["PSC Endpoint: psc-mongodb-atlas<br/>Auto-allocated Subnet IP"]
        end

        EP_GAPI["PSC Global Endpoint: psc-google-apis<br/>Internal IP: 10.20.0.100"]
    end

    subgraph GOOGLE["Google Cloud Platform"]
        API_BACKBONE["Google APIs Internal Backbone<br/>(all-apis: Storage, BigQuery, Pub/Sub)"]
    end

    subgraph SNOWFLAKE["Snowflake Producer VPC"]
        SA_SNOW["Service Attachment:<br/>snowflake-prod-host/snowflake-sa"]
        ILB_SNOW["Internal TCP/UDP Load Balancer"]
        WH_SNOW["Snowflake Data Warehouse"]
    end

    subgraph MONGO["MongoDB Atlas Producer VPC"]
        SA_MONGO["Service Attachment:<br/>mongodb-atlas-host/atlas-sa"]
        ILB_MONGO["Internal Load Balancer"]
        DB_MONGO["MongoDB Atlas Cluster"]
    end

    VM -->|Call Google APIs (10.20.0.100)| EP_GAPI
    VM -->|Query Snowflake (10.20.1.105)| EP_SNOW
    VM -->|Query MongoDB Atlas| EP_MONGO

    EP_GAPI ==>|Google Internal SDN| API_BACKBONE
    EP_SNOW ==>|Private Service Connect| SA_SNOW
    EP_MONGO ==>|Private Service Connect| SA_MONGO

    SA_SNOW --> ILB_SNOW --> WH_SNOW
    SA_MONGO --> ILB_MONGO --> DB_MONGO
```

---

## Directory Structure

```
examples/network/psc-setup/
├── psc.yaml          # Declarative specification for Google APIs and SaaS endpoints
├── main.tf           # Provisions demo VPC/subnet and instantiates private-service-connect module
├── outputs.tf        # Exports VPC details, endpoint forwarding rules, and allocated IPs
├── provider.tf       # Google provider configuration and version constraints
└── README.md         # Comprehensive architectural and operational guide
```

---

## Prerequisites & Permissions

Deploying Private Service Connect endpoints requires the following GCP IAM roles on your target project:

| IAM Role | GCP Permission Identifiers | Purpose |
| :--- | :--- | :--- |
| **Compute Network Admin** | `roles/compute.networkAdmin` | Reserve internal IP addresses and create PSC forwarding rules. |
| **Compute Security Admin** | `roles/compute.securityAdmin` | (Optional) Configure firewall rules controlling traffic to PSC endpoints. |
| **Service Usage Admin** | `roles/serviceusage.serviceUsageAdmin` | Ensure `compute.googleapis.com` is active on the project. |

---

## Declarative Configuration Walkthrough

All endpoint configurations are declared cleanly in [psc.yaml](file:///d:/GCP-DevOps-WorkSpace/gcp-terraform-custom-modules/examples/network/psc-setup/psc.yaml):

### 1. PSC for Google APIs (Global)
Reserves a global internal IP address and creates a forwarding rule directing traffic destined for Google APIs through Google's internal software-defined network:
```yaml
google_apis_endpoints:
  - name: "psc-google-apis"
    ip_address: "10.20.0.100"       # Static internal IP reserved for Google APIs
    target: "all-apis"              # Target bundle: "all-apis" or "vpc-sc"
    description: "Private endpoint for Google Cloud APIs"
```

### 2. PSC for Service Attachments (Regional SaaS)
Enables unidirectional, private connectivity to SaaS providers or producer VPCs:
- **`psc-snowflake-prod`:** Demonstrates explicit static IP reservation (`10.20.1.105`) within the consumer subnet.
- **`psc-mongodb-atlas`:** Demonstrates automatic IP allocation (`ip_address: null`), where GCP automatically assigns the next available IP address from the subnet CIDR.
```yaml
service_attachment_endpoints:
  - name: "psc-snowflake-prod"
    region: "asia-south1"
    subnet_name: "psc-demo-subnet"
    target_service_attachment: "projects/snowflake-prod-host/regions/asia-south1/serviceAttachments/snowflake-sa"
    ip_address: "10.20.1.105"
    description: "Private connection to Snowflake warehouse"

  - name: "psc-mongodb-atlas"
    region: "asia-south1"
    subnet_name: "psc-demo-subnet"
    target_service_attachment: "projects/mongodb-atlas-host/regions/asia-south1/serviceAttachments/atlas-sa"
    ip_address: null               # Auto-allocated from subnet
    description: "Private connection to MongoDB Atlas"
```

---

## Deployment Workflow

### Step 1: Authenticate to GCP
Authenticate with Application Default Credentials (ADC):
```bash
gcloud auth login
gcloud auth application-default login
```

### Step 2: Configure Project & Service Targets
Update [psc.yaml](file:///d:/GCP-DevOps-WorkSpace/gcp-terraform-custom-modules/examples/network/psc-setup/psc.yaml) with your actual project ID, IP reservations, and producer Service Attachment URIs.

### Step 3: Initialize Terraform
```bash
terraform init
```

### Step 4: Plan Deployment
```bash
terraform plan
```

### Step 5: Apply Configuration
```bash
terraform apply
```

---

## Module Outputs

| Output Name | Type | Description |
| :--- | :--- | :--- |
| `vpc_network_name` | `string` | Name of the VPC network hosting PSC endpoints. |
| `vpc_network_self_link` | `string` | Self-link of the provisioned VPC network. |
| `subnet_name` | `string` | Consumer subnet name (`psc-demo-subnet`). |
| `subnet_cidr` | `string` | Subnet CIDR range (`10.20.1.0/24`). |
| `google_apis_endpoints` | `map(object)` | Full attribute map of Google APIs PSC endpoints and forwarding rules. |
| `service_attachment_endpoints` | `map(object)` | Full attribute map of SaaS Service Attachment endpoints. |
| `google_apis_ips` | `map(string)` | Map of Google APIs endpoint names to their internal IP addresses. |
| `service_attachment_ips` | `map(string)` | Map of SaaS endpoint names to their assigned regional IP addresses. |
| `total_google_apis_endpoints` | `number` | Count of Google APIs endpoints provisioned. |
| `total_service_attachment_endpoints` | `number` | Count of SaaS Service Attachment endpoints provisioned. |

Inspect all outputs:
```bash
terraform output -json
```

---

## Verification & Operational Testing

1. **List Global Forwarding Rules (Google APIs):**
   ```bash
   gcloud compute forwarding-rules list --global
   ```
2. **List Regional Forwarding Rules (SaaS Endpoints):**
   ```bash
   gcloud compute forwarding-rules list --regions=asia-south1
   ```
3. **Verify Reserved Internal IP Addresses:**
   ```bash
   gcloud compute addresses list
   ```
4. **Test Connectivity from a Workload VM:**
   SSH into an instance inside `psc-demo-subnet` and verify network reachability:
   ```bash
   # Test Google APIs Endpoint
   curl -vk https://10.20.0.100 -H "Host: storage.googleapis.com"

   # Test SaaS Endpoint (e.g. Snowflake / MongoDB)
   nc -zv 10.20.1.105 443
   ```

---

## Architectural Comparison: PSC vs VPC Peering

| Feature | Private Service Connect (PSC) | VPC Network Peering |
| :--- | :--- | :--- |
| **IP Overlap** | **Supported:** Consumer and producer can have identical CIDRs. | **Blocked:** Overlapping CIDR ranges prevent peering. |
| **Directionality** | **Unidirectional:** Consumer initiates to endpoint; producer cannot access consumer. | **Bidirectional:** Both networks can initiate traffic by default. |
| **Transitive Routing** | **Independent:** Traffic reaches only the specific published service. | **Non-transitive:** Cannot route through a peered VPC to a 3rd network. |
| **Network Quotas** | Scales to hundreds of consumer endpoints per VPC without peering limits. | Strictly limited to maximum 25 active peering connections per VPC. |
| **Admin Control** | Fine-grained firewall policies can be applied to individual endpoint IPs. | Coarse-grained network-level peering route controls. |

---

## Troubleshooting

- **Error: `Invalid value for forwarding_rule.target`**
  For Google APIs endpoints, `target` must be either `"all-apis"` or `"vpc-sc"`. For regional SaaS endpoints, `target` must be a valid GCP Service Attachment URI (`projects/.../regions/.../serviceAttachments/...`).
- **Error: `Address already reserved`**
  Ensure the IP address requested for `google_apis_endpoints` or `service_attachment_endpoints` does not collide with existing reserved addresses in your VPC.
- **Error: `IP address not within subnet range`**
  For regional endpoints with static IP specified, ensure `ip_address` resides within the CIDR of `subnet_name`. Alternatively, set `ip_address: null` for automatic allocation.

