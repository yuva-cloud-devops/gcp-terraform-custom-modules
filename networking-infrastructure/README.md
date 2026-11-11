# Networking Infrastructure Modules for GCP

This directory contains reusable, production-ready Terraform modules for provisioning core Google Cloud Platform (GCP) networking infrastructure, modeled on the official Google Cloud Terraform modules:
- [`terraform-google-modules/network/google`](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest)
- [`terraform-google-modules/cloud-router/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest)
- [`terraform-google-modules/cloud-nat/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/latest)

---

## Design Principles

1. **Infrastructure as Data**:
   Network topologies, CIDR allocation, BGP routing, egress NAT policies, Private Service Access ranges, and firewall rules are declared through structured YAML configurations.
2. **Security by Default**:
   - `auto_create_subnetworks` is strictly disabled (`false`).
   - Private Google Access is enabled by default across all subnets.
   - Cloud NAT provides controlled egress for private workloads.
   - Private Service Access enables private connectivity to Cloud SQL, Memorystore, and Filestore without public IPs.
3. **Enterprise BGP & Hybrid Ready**:
   Cloud Routers support ASN configuration, custom BGP route advertisements, router interfaces, and BGP peers with BFD.

---

## Module Catalog

| Module | Description | Status |
|--------|-------------|:------:|
| [`vpc-subnet-router-nat-firewall`](./vpc-subnet-router-nat-firewall/) | End-to-end VPC, multi-region subnets, Cloud Routers with BGP, Cloud NAT gateways, Ingress/Egress Firewalls, and Private Service Access driven by YAML. | **Stable / Production** |

---

## Directory Structure

```
networking-infrastructure/
├── README.md                                 # Domain documentation (this file)
└── vpc-subnet-router-nat-firewall/           # Core networking module
    ├── 0-locals.tf                           # YAML configuration parser & normalizer
    ├── 1-vpc.tf                              # VPC network resources
    ├── 2-subnetworks.tf                      # Subnets, secondary IP ranges & VPC flow logs
    ├── 3-cloud-router.tf                     # Cloud Routers, BGP config, interfaces & peers
    ├── 4-cloud-nat.tf                        # Cloud NAT gateways, port allocation & logging
    ├── 5-firewall.tf                         # Ingress & Egress firewall rules
    ├── 6-private-service-access.tf           # Private Service Access (VPC Peering for Cloud SQL/Redis)
    ├── variables.tf                          # Input variables
    ├── outputs.tf                            # Comprehensive output definitions & lookup maps
    ├── versions.tf                           # Terraform and provider version constraints
    └── README.md                             # Detailed module documentation
```

---

## Quick Start

```hcl
module "networking" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/vpc-subnet-router-nat-firewall?ref=main"
  config_file_path = "${path.module}/network-config.yaml"
}
```

For full YAML configuration details and output schemas, refer to the [vpc-subnet-router-nat-firewall README](./vpc-subnet-router-nat-firewall/README.md).
