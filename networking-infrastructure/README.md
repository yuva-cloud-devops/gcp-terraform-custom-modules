# Networking Infrastructure Modules for GCP

This directory contains reusable, production-ready Terraform modules for provisioning core Google Cloud Platform (GCP) networking infrastructure.

The networking layer serves as the foundation for all workloads across Google Cloud (Compute Engine, Google Kubernetes Engine, Cloud Run, Cloud SQL, and private interconnects).

---

## Design Principles

1. **Infrastructure as Data**:
   Network topologies, CIDR allocation, egress NAT policies, and firewall rules are declared through structured YAML configurations, separating environment definitions from Terraform logic.
2. **Security by Default**:
   - `auto_create_subnetworks` is strictly disabled (`false`) on all VPCs.
   - Private Google Access is enabled by default across all subnets to prevent compute instances from needing external public IPs to communicate with GCP APIs.
   - Cloud NAT provides secure egress for instances in private subnets.
   - Firewall rules default to least-privilege principles.
3. **Multi-VPC & Multi-Tenant Support**:
   Modules are engineered to handle multi-VPC topologies (e.g., Core Workloads, DMZ/Bastion, Shared VPC, Transit Hubs) in a single configuration without code duplication.
4. **First-Class GKE Integration**:
   Subnet modules natively support secondary CIDR ranges for GKE Pod and Service IP allocations.

---

## Module Catalog

| Module | Description | Status |
|--------|-------------|:------:|
| [`vpc-subnet-router-nat-firewall`](./vpc-subnet-router-nat-firewall/) | Multi-VPC, custom subnets with secondary ranges, Cloud Routers, Cloud NAT gateways, and dynamic firewall rules driven by YAML. | **Stable / Production** |

---

## Directory Structure

```
networking-infrastructure/
├── README.md                                 # Domain documentation (this file)
└── vpc-subnet-router-nat-firewall/           # Core networking module
    ├── 0-locals.tf                           # YAML configuration parser and key flattener
    ├── 1-vpc.tf                              # VPC network resources
    ├── 2-subnetworks.tf                      # Subnets & secondary IP ranges
    ├── 3-cloud-router.tf                     # Cloud Router resources
    ├── 4-cloud-nat.tf                        # Cloud NAT gateway resources
    ├── 5-firewall.tf                         # Dynamic firewall rules (allow/deny)
    ├── variables.tf                          # Input variables
    ├── outputs.tf                            # Comprehensive output definitions & lookup maps
    ├── versions.tf                           # Terraform and provider version constraints
    └── README.md                             # Detailed module documentation
```

---

## Quick Start

### 1. Create a `network-config.yaml`

```yaml
project_id: "your-gcp-project-id"

vpcs:
  - name: "core-workload-vpc"
    routing_mode: "GLOBAL"
    subnets:
      - name: "apps-subnet"
        ip_cidr: "10.10.1.0/24"
        region: "us-central1"
        private_access: true
    nats:
      - name: "core-nat"
        region: "us-central1"
        log_filter: "ERRORS_ONLY"
    firewall_rules:
      - name: "allow-internal"
        direction: "INGRESS"
        source_ranges: ["10.10.0.0/16"]
        allows:
          - protocol: "all"
```

### 2. Invoke the module in your Terraform code

```hcl
module "networking" {
  source           = "./networking-infrastructure/vpc-subnet-router-nat-firewall"
  config_file_path = "${path.module}/network-config.yaml"
}
```

For detailed usage, variable definitions, and output schemas, refer to the [vpc-subnet-router-nat-firewall README](./vpc-subnet-router-nat-firewall/README.md).
