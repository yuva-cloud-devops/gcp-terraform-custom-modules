# Networking Infrastructure Modules for GCP

This directory contains reusable, production-ready Terraform modules for provisioning core Google Cloud Platform (GCP) networking infrastructure, modeled on enterprise best practices and the official Google Cloud Cloud Foundation Fabric:
- [`terraform-google-modules/network/google`](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest)
- [`terraform-google-modules/cloud-router/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest)
- [`terraform-google-modules/cloud-nat/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/latest)

---

## Design Principles

1. **Infrastructure as Data**:
   Network topologies, CIDR allocation, BGP routing, egress NAT policies, Private Service Access ranges, firewall rules, Shared VPC cross-project attachments, hierarchical firewall policies, Cloud DNS zones, and Private Service Connect endpoints are declared through structured, human-readable YAML configurations.
2. **Security by Default**:
   - `auto_create_subnetworks` is strictly disabled (`false`).
   - Private Google Access is enabled by default across all subnets.
   - Cloud NAT provides controlled egress for private workloads without public IPs.
   - Private Service Access enables private connectivity to Cloud SQL, Memorystore, and Filestore.
   - Least-privilege Shared VPC subnet delegations (`roles/compute.networkUser` scoped to individual subnets rather than host project-wide).
3. **Enterprise BGP & Hybrid Ready**:
   Cloud Routers support ASN configuration, custom BGP route advertisements, router interfaces, and BGP peers with BFD.
4. **Hierarchical Perimeter Guardrails**:
   Organization- and Folder-level Hierarchical Firewall Policies enforce non-negotiable security rules (such as universal internet SSH/RDP blocks) that evaluate prior to any project-level VPC firewall rules.
5. **Hybrid & Private DNS Resolution**:
   Cloud DNS modules support Private Authoritative Zones, On-Premises DNS Forwarding via Cloud VPN/Interconnect, Cross-VPC Peering, and Restricted Google APIs VIP routing (`199.36.153.4/30`) for VPC Service Controls.
6. **Zero-Trust Private Service Connect (PSC)**:
   Enables private, unidirectional consumption of Google Cloud APIs and third-party SaaS services (Snowflake, MongoDB Atlas, Databricks) via internal IP addresses without VPC peering limits or IP overlap constraints.
7. **High-Throughput VPC Network Peering**:
   Enables low-latency, line-rate RFC 1918 IPv4/IPv6 inter-VPC communication across projects with automated bi-directional handshakes and dynamic custom route propagation.
8. **Resilient Hybrid Connectivity (HA Cloud VPN)**:
   Provides 99.99% SLA site-to-site IPsec VPN connectivity to on-premises data centers and third-party clouds with dual redundant interfaces, dynamic eBGP routing, and sub-second BFD failover.
9. **Cross-Project Scalability (Shared VPC)**:
   Clear separation of duties between central Network Administrators (NetOps), Security Operations (SecOps), and application teams (AppOps/DevOps).

---

## Module Catalog

| Module | Description | Status |
|--------|-------------|:------:|
| [`vpc-subnet-router-nat-firewall`](./vpc-subnet-router-nat-firewall/) | End-to-end VPC, multi-region subnets, Cloud Routers with BGP, Cloud NAT gateways, Ingress/Egress Firewalls, and Private Service Access driven by YAML. | **Stable / Production** |
| [`shared-vpc`](./shared-vpc/) | Declarative Shared VPC orchestration via YAML. Enables Host Project, attaches Service Projects, automates GKE/Compute/Cloud Run service agent permissions, and provisions least-privilege subnetwork IAM delegations. | **Stable / Production** |
| [`hierarchical-firewalls`](./hierarchical-firewalls/) | Enterprise Hierarchical Firewall Policies attached at Folder or Organization level. Enforces centralized, non-negotiable SecOps perimeter guardrails across all nested VPC networks. | **Stable / Production** |
| [`cloud-dns`](./cloud-dns/) | Declarative Google Cloud DNS management via YAML. Provisions Private Authoritative Zones, Hybrid DNS Forwarding to on-premises resolvers, Cross-VPC Peering, and Restricted Google APIs VIP routing. | **Stable / Production** |
| [`private-service-connect`](./private-service-connect/) | Declarative Private Service Connect (PSC) management via YAML. Provisions private endpoints for Google APIs (Global) and published SaaS / Producer Service Attachments (Regional). | **Stable / Production** |
| [`network-peering`](./network-peering/) | Declarative VPC Network Peering via YAML. Provisions bi-directional or uni-directional peering connections with automated reverse handshake and custom route propagation. | **Stable / Production** |
| [`ha-cloud-vpn`](./ha-cloud-vpn/) | Declarative High Availability (HA) Cloud VPN via YAML. Provisions dual-interface gateways, external peer devices, redundant IPsec tunnels, and eBGP sessions for 99.99% SLA hybrid connectivity. | **Stable / Production** |

---

## Directory Structure

```
networking-infrastructure/
├── README.md                                 # Domain documentation (this file)
├── cloud-dns/                                # Google Cloud DNS managed zones & records
│   ├── 0-locals.tf                           # YAML parser, FQDN normalizer & multi-tier network resolver
│   ├── 1-managed-zones.tf                    # Managed zones (private, forwarding, peering)
│   ├── 2-dns-records.tf                      # Authoritative DNS record sets
│   ├── variables.tf                          # Input variables (yaml_config_path, network_self_link)
│   ├── outputs.tf                            # Output definitions, nameservers & record metrics
│   ├── versions.tf                           # Terraform and Google provider constraints
│   └── README.md                             # Detailed Cloud DNS module documentation
├── ha-cloud-vpn/                             # High Availability (HA) Cloud VPN module (99.99% SLA)
│   ├── 0-locals.tf                           # YAML parser, gateway mapping & tunnel flattening
│   ├── 1-vpn-gateway.tf                      # HA VPN Gateway resources
│   ├── 2-external-gateway.tf                 # On-premises external peer gateway definitions
│   ├── 3-tunnels.tf                          # Redundant IPsec VPN tunnel resources
│   ├── 4-router-interface.tf                 # Cloud Router point-to-point BGP interfaces
│   ├── 5-router-peer.tf                      # Cloud Router eBGP peering sessions with BFD
│   ├── variables.tf                          # Input variables (yaml_config_path, network_self_link)
│   ├── outputs.tf                            # Gateway IPs, tunnel IDs, interfaces & peers
│   ├── versions.tf                           # Terraform and Google provider constraints
│   └── README.md                             # Detailed HA Cloud VPN module documentation
├── hierarchical-firewalls/                   # Organization & Folder hierarchical firewall policies
│   ├── 0-locals.tf                           # YAML configuration parser & deterministic rule indexing
│   ├── 1-firewall.tf                         # Hierarchical firewall policy container resource
│   ├── 2-rules.tf                            # Dynamic firewall rules with Layer 4 matching
│   ├── 3-firewall-association.tf             # Policy association to target Folder or Organization
│   ├── variables.tf                          # Input variables (yaml_config_path)
│   ├── outputs.tf                            # Output definitions & rule summaries
│   ├── versions.tf                           # Terraform and Google provider constraints
│   └── README.md                             # Detailed Hierarchical Firewalls module documentation
├── network-peering/                          # VPC Network Peering module
│   ├── 0-locals.tf                           # YAML parser & reverse peering partitioner
│   ├── main.tf                               # Forward and automated reverse peering resources
│   ├── variables.tf                          # Input variables (yaml_config_path, local_network_self_link)
│   ├── outputs.tf                            # Comprehensive peering state outputs & counts
│   ├── versions.tf                           # Terraform and Google provider constraints
│   └── README.md                             # Detailed VPC Peering module documentation
├── private-service-connect/                  # Private Service Connect (Google APIs & SaaS endpoints)
│   ├── 0-locals.tf                           # YAML parser & subnetwork URI normalizer
│   ├── 1-psc-apis.tf                         # Global IP & Forwarding Rule for Google APIs
│   ├── 2-psc-services.tf                     # Regional IP & Forwarding Rule for Service Attachments
│   ├── variables.tf                          # Input variables (yaml_config_path, network_self_link)
│   ├── outputs.tf                            # Endpoint details, IPs & forwarding rules
│   ├── versions.tf                           # Terraform and Google provider constraints
│   └── README.md                             # Detailed Private Service Connect module documentation
├── shared-vpc/                               # Shared VPC & cross-project networking module
│   ├── 0-locals.tf                           # YAML configuration parser & robot service agent derivation
│   ├── 1-host-project.tf                     # Host project enablement
│   ├── 2-service-projects.tf                 # Service project dynamic attachment
│   ├── 3-gke-host-level-permission.tf        # GKE service agent host-level IAM permissions
│   ├── 4-custom-subnet-iam.tf                # Fine-grained subnet networkUser delegations
│   ├── variables.tf                          # Input variables
│   ├── outputs.tf                            # Output definitions
│   ├── versions.tf                           # Terraform and provider constraints
│   └── README.md                             # Detailed Shared VPC module documentation
└── vpc-subnet-router-nat-firewall/           # Core VPC networking module
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

## Quick Start Workflows

### 1. Provision Centralized Security Guardrails
Enforce organization- or folder-level guardrails before deploying VPCs:
```hcl
module "hierarchical_firewalls" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/hierarchical-firewalls?ref=main"
  yaml_config_path = "${path.module}/firewalls.yaml"
}
```

### 2. Provision Base VPC Network
```hcl
module "networking" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/vpc-subnet-router-nat-firewall?ref=main"
  config_file_path = "${path.module}/network-config.yaml"
}
```

### 3. Attach Service Projects & Subnet Delegations via Shared VPC
```hcl
module "shared_vpc" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/shared-vpc?ref=main"
  yaml_config_path = "${path.module}/shared_vpc.yaml"

  depends_on = [module.networking]
}
```

### 4. Deploy Enterprise Cloud DNS Zones
```hcl
module "cloud_dns" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/cloud-dns?ref=main"
  yaml_config_path  = "${path.module}/dns.yaml"
  network_self_link = module.networking.vpcs["main-landing-zone-vpc"].self_link
}
```

### 5. Configure Private Service Connect (PSC) Endpoints
```hcl
module "psc" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/private-service-connect?ref=main"
  yaml_config_path  = "${path.module}/psc.yaml"
  network_self_link = module.networking.vpcs["main-landing-zone-vpc"].self_link
}
```

### 6. Connect VPCs via VPC Network Peering
```hcl
module "vpc_peering" {
  source                  = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/network-peering?ref=main"
  yaml_config_path        = "${path.module}/peering.yaml"
  local_network_self_link = module.networking.vpcs["main-landing-zone-vpc"].self_link
}
```

### 7. Establish Hybrid Site-to-Site Connectivity via HA Cloud VPN
```hcl
module "ha_vpn" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/ha-cloud-vpn?ref=main"
  yaml_config_path  = "${path.module}/vpn.yaml"
  network_self_link = module.networking.vpcs["main-landing-zone-vpc"].self_link
  router_name       = "cr-landing-zone-main"
}
```

---

## Module Documentation & Examples

- **Core VPC Networking:**
  - Module: [vpc-subnet-router-nat-firewall README](./vpc-subnet-router-nat-firewall/README.md)
  - Example: [Basic Multi-VPC Setup README](../examples/network/basic-vpc-setup/README.md)
- **Shared VPC Networking:**
  - Module: [Shared VPC README](./shared-vpc/README.md)
  - Example: [Shared VPC Setup README](../examples/network/shared-vpc-setup/README.md)
- **Hierarchical Firewalls:**
  - Module: [Hierarchical Firewalls README](./hierarchical-firewalls/README.md)
  - Example: [Hierarchical Firewall Setup README](../examples/network/firewall-setup/README.md)
- **Cloud DNS:**
  - Module: [Cloud DNS README](./cloud-dns/README.md)
  - Example: [Cloud DNS Setup README](../examples/network/dns-setup/README.md)
- **Private Service Connect:**
  - Module: [Private Service Connect README](./private-service-connect/README.md)
  - Example: [Private Service Connect Setup README](../examples/network/psc-setup/README.md)
- **VPC Network Peering:**
  - Module: [VPC Network Peering README](./network-peering/README.md)
  - Example: [VPC Peering Setup README](../examples/network/peering-setup/README.md)
- **High Availability Cloud VPN:**
  - Module: [HA Cloud VPN README](./ha-cloud-vpn/README.md)
  - Example: [HA Cloud VPN Setup README](../examples/network/vpn-setup/README.md)
