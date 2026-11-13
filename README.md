# Google Cloud Platform (GCP) Terraform Custom Modules

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Provider](https://img.shields.io/badge/Provider-Google%20%3E%3D5.0.0-4285F4?logo=google-cloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A collection of enterprise-grade, highly reusable, and production-tested Terraform custom modules for provisioning secure and scalable Google Cloud Platform (GCP) infrastructure.

---

## Design Principles

- **Data-Driven Infrastructure**: Complex cloud landing zones and network topologies—including resource hierarchies, Project Factory setups, VPCs, multi-region subnets, Cloud Routers with BGP, Cloud NAT gateways, Private Service Access, and firewall policies—are declared via human-readable YAML configurations.
- **Official Module Alignment**: Built following the architecture and feature sets of official Google Cloud Terraform modules:
  - Resource hierarchy & project factory best practices ([`terraform-google-modules/project-factory`](https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest))
  - Core networking ([`terraform-google-modules/network/google`](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest))
  - Cloud Router with BGP ([`terraform-google-modules/cloud-router/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest))
  - Cloud NAT ([`terraform-google-modules/cloud-nat/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/latest))
- **Security by Default**:
  - Non-authoritative IAM member bindings (`google_*_iam_member`) to prevent accidental permission stripping.
  - Automatic deprivileging of the default Compute Engine service account.
  - Project deletion protection (`deletion_policy = "PREVENT"`).
  - Private-only subnets, Private Google Access, Private Service Access for managed databases, Cloud NAT for controlled egress, and explicit least-privilege firewall rules.

---

## Repository Structure

```
gcp-terraform-custom-modules/
├── foundation-infrastructure/                # Cloud Landing Zone & Hierarchy Factory
│   ├── 0-locals.tf                           # YAML parser & schema flattening pipeline
│   ├── 1-org-iam.tf                          # Organization-level IAM member bindings
│   ├── 2-folders.tf                          # Top-level & nested sub-folder hierarchy
│   ├── 3-projects.tf                         # Project Factory (Billing, prefix, random suffix)
│   ├── 4-iam.tf                              # Folder IAM with CEL conditions & SA deprivileging
│   ├── 5-apis.tf                             # Dynamic API enablement per project
│   ├── 6-users-groups.tf                     # Project-level IAM with CEL conditions
│   ├── 7-custom-service-accounts.tf          # Dedicated workload SAs & project role assignments
│   ├── variables.tf                          # Configuration path variable
│   ├── outputs.tf                            # Output maps for folders, projects, & service accounts
│   ├── versions.tf                           # Provider and Terraform constraints
│   └── README.md                             # Foundation module documentation
├── networking-infrastructure/                # Core networking domain
│   ├── README.md                             # Networking overview & domain docs
│   └── vpc-subnet-router-nat-firewall/       # VPC, subnets, BGP routers, NAT, firewalls & PSA
│       ├── 0-locals.tf
│       ├── 1-vpc.tf
│       ├── 2-subnetworks.tf
│       ├── 3-cloud-router.tf
│       ├── 4-cloud-nat.tf
│       ├── 5-firewall.tf
│       ├── 6-private-service-access.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── examples/                                 # Reference implementations & sample setups
│   ├── foundation/                           # Foundation module deployment example
│   └── network/                              # Networking module deployment example
├── .gitignore                                # Git ignore rules
└── README.md                                 # Root repository documentation
```

---

## Module Catalog

| Domain | Module | Description | Directory |
|---|---|---|---|
| **Foundation** | **Resource Hierarchy & Project Factory** | Declarative GCP Landing Zone via YAML. Provisions multi-tier folder hierarchy, creates projects with billing attachment, enables APIs, assigns organization/folder/project IAM (with CEL conditions), creates custom workload service accounts, and strips default Compute Engine service account privileges. | [`foundation-infrastructure`](./foundation-infrastructure/) |
| **Networking** | **VPC, Subnets, BGP Router, NAT, Firewall & PSA** | End-to-end VPC networking provisioned via YAML. Supports multi-region subnets, secondary ranges for GKE, VPC flow logs, Cloud Routers with detailed BGP configuration, Cloud NAT gateways, Private Service Access (`servicenetworking.googleapis.com`), and ingress/egress firewall rules. | [`networking-infrastructure/vpc-subnet-router-nat-firewall`](./networking-infrastructure/vpc-subnet-router-nat-firewall/) |

---

## Quick Examples

### Example 1: Foundation Infrastructure & Project Factory

#### 1. Define your resource hierarchy in `hierarchy.yaml`:

```yaml
organization_id: "123456789012"
billing_account_id: "012345-56789A-BCDEF0"

# Organization IAM
organization_iam:
  - role: "roles/resourcemanager.organizationAdmin"
    members:
      - "group:gcp-org-admins@mycompany.com"

# Multi-Tier Folders
top_level_folders:
  - name: "workloads"
    iam:
      - role: "roles/resourcemanager.folderViewer"
        members: ["group:cloud-leads@mycompany.com"]

sub_folders:
  - name: "development"
    parent: "workloads"
    iam:
      - role: "roles/viewer"
        members: ["group:developers@mycompany.com"]

# Projects (Project Factory)
projects:
  - name: "ecommerce-api"
    prefix: "acme-dev"
    target_folder: "development"
    random_id: true
    deprivilege_default_sa: true
    apis:
      - "compute.googleapis.com"
      - "container.googleapis.com"
      - "storage.googleapis.com"
    labels:
      environment: "dev"
      cost_center: "engineering"
    iam:
      - role: "roles/viewer"
        members: ["group:developers@mycompany.com"]
    custom_service_accounts:
      - account_id: "ecommerce-backend-sa"
        display_name: "Ecommerce Backend Workload Identity"
        roles:
          - "roles/storage.objectUser"
          - "roles/logging.logWriter"
```

#### 2. Reference the Foundation module in your `main.tf`:

```hcl
module "foundation" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//foundation-infrastructure?ref=main"
  yaml_config_path = "${path.module}/hierarchy.yaml"
}

output "folders" {
  value = module.foundation.folders
}

output "projects" {
  value = module.foundation.projects
}
```

---

### Example 2: Networking Infrastructure

#### 1. Define your network specification in `network-config.yaml`:

```yaml
project_id: yuvaraj-internal-project
region: asia-south1

tags:
  provisioned_by: terraform
  environment: dev
  project: gcp-platform-foundation-terraform

network:
  vpc:
    network_name: platform-foundation-vpc

    # Optional Private Service Access (for Cloud SQL, Memorystore, etc.)
    private_service_access:
      enabled: true
      name: google-managed-services-psa
      prefix_length: 16

    subnets:
      - subnet_name: private-subnet-mumbai
        subnet_ip: 10.20.1.0/24
        subnet_region: asia-south1
        subnet_private_access: true
      - subnet_name: private-subnet-singapore
        subnet_ip: 10.30.1.0/24
        subnet_region: asia-southeast1
        subnet_private_access: true

    firewall_rules:
      ingress:
        - name: allow-iap-ssh
          source_ranges:
            - 35.235.240.0/20
          target_tags:
            - allow-iap-ssh
          ports:
            - "22"
      egress:
        - name: allow-internet
          destination_ranges:
            - 0.0.0.0/0
          ports:
            - "80"
            - "443"

  router:
    - name: cloud-router-mumbai
      region: asia-south1
      bgp:
        asn: "65001"
    - name: cloud-router-singapore
      region: asia-southeast1
      bgp:
        asn: "65002"

  nat:
    - name: cloud-nat-mumbai
      region: asia-south1
      router_name: cloud-router-mumbai
    - name: cloud-nat-singapore
      region: asia-southeast1
      router_name: cloud-router-singapore
```

#### 2. Reference the Networking module in your `main.tf`:

```hcl
module "networking" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/vpc-subnet-router-nat-firewall?ref=main"
  config_file_path = "${path.module}/network-config.yaml"
}

output "vpc_id" {
  value = module.networking.vpc_ids["platform-foundation-vpc"]
}

output "mumbai_subnet_id" {
  value = module.networking.subnet_ids["private-subnet-mumbai"]
}
```

---

## Prerequisites

1. **Terraform CLI**: Version `>= 1.5.0`
2. **Google Cloud SDK (`gcloud`)**: Installed and authenticated (`gcloud auth application-default login`)
3. **Required IAM Permissions**:
   - **For Foundation**: `roles/resourcemanager.organizationAdmin`, `roles/resourcemanager.folderAdmin`, and `roles/billing.user` (or `roles/billing.admin`)
   - **For Networking**: `roles/compute.networkAdmin`, `roles/compute.securityAdmin`, and `roles/servicenetworking.networksAdmin`
4. **Required GCP APIs Enabled** (on administrative/seed project):
   - `cloudresourcemanager.googleapis.com`
   - `serviceusage.googleapis.com`
   - `cloudbilling.googleapis.com`
   - `iam.googleapis.com`
   - `compute.googleapis.com`
   - `servicenetworking.googleapis.com` (when Private Service Access is enabled)

---

## License

This repository is distributed under the [MIT License](LICENSE).
