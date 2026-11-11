# Google Cloud Platform (GCP) Terraform Custom Modules

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Provider](https://img.shields.io/badge/Provider-Google%20%3E%3D5.0.0-4285F4?logo=google-cloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A collection of enterprise-grade, highly reusable, and production-tested Terraform custom modules for provisioning secure and scalable Google Cloud Platform (GCP) infrastructure.

---

## Design Principles

- **Data-Driven Infrastructure**: Complex network topologies—including VPCs, multi-region subnets, Cloud Routers with BGP, Cloud NAT gateways, Private Service Access, and firewall policies—are declared via human-readable YAML configurations.
- **Official Module Alignment**: Built following the architecture and feature sets of [`terraform-google-modules/network/google`](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest), [`terraform-google-modules/cloud-router/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest), and [`terraform-google-modules/cloud-nat/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/latest).
- **Security by Default**: Private-only subnets, Private Google Access, Private Service Access for managed databases, Cloud NAT for controlled egress, and explicit least-privilege firewall rules.

---

## Repository Structure

```
gcp-terraform-custom-modules/
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
├── .gitignore                                # Git ignore rules (includes examples/ & state)
└── README.md                                 # Root repository documentation
```

---

## Module Catalog

### Networking Infrastructure

| Module | Description | Directory |
|---|---|---|
| **VPC, Subnets, BGP Router, NAT, Firewall & PSA** | End-to-end VPC networking provisioned via YAML. Supports multi-region subnets, secondary ranges for GKE, VPC flow logs, Cloud Routers with detailed BGP configuration, Cloud NAT gateways, Private Service Access (`servicenetworking.googleapis.com`), and ingress/egress firewall rules. | [`networking-infrastructure/vpc-subnet-router-nat-firewall`](./networking-infrastructure/vpc-subnet-router-nat-firewall/) |

---

## Quick Example: Using the Networking Module

### 1. Define your network specification in `network-config.yaml`:

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

### 2. Reference the module in your `main.tf`:

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
3. **Required GCP APIs Enabled**:
   - `compute.googleapis.com`
   - `servicenetworking.googleapis.com` (required when Private Service Access is enabled)
