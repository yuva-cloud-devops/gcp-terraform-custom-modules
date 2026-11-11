# Google Cloud Platform (GCP) Terraform Custom Modules

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Provider](https://img.shields.io/badge/Provider-Google%20%3E%3D5.0.0-4285F4?logo=google-cloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A collection of enterprise-grade, highly reusable, and production-tested Terraform custom modules for provisioning secure and scalable Google Cloud Platform (GCP) infrastructure.

---

## Design Principles

- **Data-Driven Infrastructure**: Complex, multi-resource topologies (e.g., multiple VPCs, subnets, NAT gateways, and firewall policies) can be declared cleanly via human-readable YAML configurations, decoupling code logic from environmental data.
- **Security by Default**: Modules follow Google Cloud best practices and CIS GCP Benchmark recommendations—including private-only subnets, Private Google Access, Cloud NAT for controlled egress, and explicit least-privilege firewall rules.
- **Modularity & Composition**: Designed to chain cleanly into downstream modules (such as GKE, Cloud SQL, Compute Engine, and Cloud Run) using rich lookup maps and structured outputs.
- **Consistency**: Standardized file conventions, naming standards, and version pinning across all modules.

---

## Repository Structure

```
gcp-terraform-custom-modules/
├── networking-infrastructure/                # Core networking domain
│   ├── README.md                             # Networking overview & domain docs
│   └── vpc-subnet-router-nat-firewall/       # Multi-VPC, subnets, routers, NAT & firewalls
│       ├── 0-locals.tf
│       ├── 1-vpc.tf
│       ├── 2-subnetworks.tf
│       ├── 3-cloud-router.tf
│       ├── 4-cloud-nat.tf
│       ├── 5-firewall.tf
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
| **Multi-VPC, Subnets, Router, NAT & Firewall** | End-to-end multi-VPC networking provisioned via YAML. Supports secondary IP ranges for GKE, Cloud Routers, auto-allocating Cloud NAT gateways, and dynamic ingress/egress firewall rules. | [`networking-infrastructure/vpc-subnet-router-nat-firewall`](./networking-infrastructure/vpc-subnet-router-nat-firewall/) |

---

## Prerequisites

Before utilizing these modules, ensure your local environment or CI/CD runner has:

1. **Terraform CLI**: Version `>= 1.5.0` installed.
2. **Google Cloud SDK (`gcloud`)**: Installed and authenticated.
3. **GCP Authentication**:
   ```bash
   gcloud auth application-default login
   ```
   Or set the service account credentials via environment variable:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
   ```
4. **Required GCP APIs Enabled**:
   - `compute.googleapis.com`

---

## Quick Example: Using the Networking Module

### 1. Define your network specification in `network-config.yaml`:

```yaml
project_id: "my-gcp-project-id"

vpcs:
  - name: "prod-vpc"
    routing_mode: "GLOBAL"

    subnets:
      - name: "prod-apps"
        ip_cidr: "10.10.1.0/24"
        region: "us-central1"
        private_access: true
        secondary_ranges:
          - name: "gke-pods"
            ip_cidr: "10.20.0.0/16"
          - name: "gke-services"
            ip_cidr: "10.30.0.0/20"

    nats:
      - name: "prod-nat"
        region: "us-central1"
        log_filter: "ERRORS_ONLY"

    firewall_rules:
      - name: "allow-internal"
        direction: "INGRESS"
        source_ranges: ["10.10.0.0/16"]
        allows:
          - protocol: "all"
```

### 2. Reference the module in your root `main.tf`:

```hcl
module "networking" {
  source           = "./networking-infrastructure/vpc-subnet-router-nat-firewall"
  config_file_path = "${path.module}/network-config.yaml"
}

# Access convenient lookup outputs for downstream resources
output "vpc_id" {
  value = module.networking.vpc_ids["prod-vpc"]
}

output "subnet_id" {
  value = module.networking.subnet_ids["prod-vpc/prod-apps"]
}
```

---

## Development & Contribution Guidelines

When contributing new modules or modifying existing ones:

1. **Format Code**:
   Always format all Terraform files before committing:
   ```bash
   terraform fmt -recursive
   ```

2. **Validate Syntax**:
   Ensure configuration files validate cleanly:
   ```bash
   terraform validate
   ```

3. **Documentation**:
   - Keep module-level `README.md` files updated with requirements, inputs, outputs, and example configurations.
   - Use descriptive resource names and structured comments.

4. **Git Hygiene**:
   - Local test directories, `.tfstate`, and `examples/` are excluded by `.gitignore`. Do not commit credentials, test state files, or cached provider binaries.
