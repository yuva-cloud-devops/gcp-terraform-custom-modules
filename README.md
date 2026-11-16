# Google Cloud Platform (GCP) Terraform Custom Modules

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Provider](https://img.shields.io/badge/Provider-Google%20%3E%3D5.0.0-4285F4?logo=google-cloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A collection of enterprise-grade, highly reusable, and production-tested Terraform custom modules for provisioning secure and scalable Google Cloud Platform (GCP) infrastructure.

---

## Design Principles

- **Data-Driven Infrastructure**: Complex cloud landing zones and network topologies—including resource hierarchies, Project Factory setups, organizational governance, VPCs, multi-region subnets, Cloud Routers with BGP, Cloud NAT gateways, Private Service Access, hierarchical firewall policies, and Cloud DNS—are declared via human-readable YAML configurations.
- **Official Module Alignment**: Built following the architecture and feature sets of official Google Cloud Terraform modules:
  - Resource hierarchy & project factory best practices ([`terraform-google-modules/project-factory`](https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest))
  - Core networking ([`terraform-google-modules/network/google`](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest))
  - Cloud Router with BGP ([`terraform-google-modules/cloud-router/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest))
  - Cloud NAT ([`terraform-google-modules/cloud-nat/google`](https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/latest))
- **Enterprise Governance & Security by Default**:
  - Centralized **Essential Contacts** for automated security, incident, and billing notifications.
  - Cryptographic **Resource Manager Tags** at the organization root for Attribute-Based Access Control (ABAC) and Organization Policies.
  - Organization- and Folder-level **Hierarchical Firewall Policies** enforcing non-negotiable security guardrails before project VPC firewalls.
  - **Hybrid & Private Cloud DNS** with support for on-premises forwarding via Cloud VPN/Interconnect and zero-egress Restricted Google APIs routing (`199.36.153.4/30`).
  - **Zero-Trust Private Service Connect (PSC)** for private, overlapping-IP-safe connectivity to Google APIs (`all-apis`, `vpc-sc`) and producer-published microservices/SaaS without VPC peering.
  - **High-Throughput VPC Network Peering** for direct, low-latency RFC 1918 cross-VPC communication with automated bi-directional handshakes and dynamic route exchanges.
  - **99.99% SLA High Availability (HA) Cloud VPN** providing dual-interface IPsec site-to-site connectivity with dynamic eBGP routing and sub-second BFD failover.
  - Hard project protection via **Resource Manager Liens** (`resourcemanager.projects.delete`).
  - Automatic deprivileging of the default Compute Engine service account (`roles/editor` revocation).
  - Non-authoritative IAM member bindings (`google_*_iam_member`) with Common Expression Language (CEL) conditions.
  - Private-only subnets, Private Google Access, Private Service Access for managed databases, Cloud NAT for controlled egress, and explicit least-privilege firewall rules.

---

## Repository Structure

```
gcp-terraform-custom-modules/
├── foundation-infrastructure/                # Cloud Landing Zone & Project Factory
│   ├── 0-locals.tf                           # YAML parser & schema flattening pipeline
│   ├── 1-org-iam.tf                          # Organization-level IAM member bindings
│   ├── 2-folders.tf                          # Top-level & nested sub-folder hierarchy
│   ├── 3-projects.tf                         # Project Factory (Billing, prefix, random suffix)
│   ├── 4-iam.tf                              # Folder IAM with CEL conditions & SA deprivileging
│   ├── 5-apis.tf                             # Dynamic API enablement per project
│   ├── 6-users-groups.tf                     # Project-level IAM with CEL conditions
│   ├── 7-custom-service-accounts.tf          # Dedicated workload SAs & project role assignments
│   ├── 8-project-lien.tf                     # Project deletion liens (Hard deletion protection)
│   ├── 9-resource-tag-binding.tf             # Cryptographic resource tag bindings (ABAC)
│   ├── 10-governance.tf                      # Essential contacts & organization tag taxonomy
│   ├── variables.tf                          # Configuration path variable
│   ├── outputs.tf                            # Output maps for folders, projects, SAs, and tags
│   ├── versions.tf                           # Provider and Terraform constraints
│   └── README.md                             # Foundation module documentation
├── networking-infrastructure/                # Core networking domain
│   ├── README.md                             # Networking overview & domain docs
│   ├── cloud-dns/                            # Google Cloud DNS managed zones & records
│   │   ├── 0-locals.tf                       # YAML parser, FQDN normalizer & multi-tier network resolver
│   │   ├── 1-managed-zones.tf                # Managed zones (private, forwarding, peering)
│   │   ├── 2-dns-records.tf                  # Authoritative DNS record sets
│   │   ├── variables.tf                      # Input variables
│   │   ├── outputs.tf                        # Output definitions, nameservers & record metrics
│   │   ├── versions.tf                       # Provider constraints
│   │   └── README.md                         # Detailed module documentation
│   ├── ha-cloud-vpn/                         # High Availability (HA) Cloud VPN (99.99% SLA)
│   │   ├── 0-locals.tf                       # YAML parser, gateway mapping & tunnel flattening
│   │   ├── 1-vpn-gateway.tf                  # HA VPN Gateway resources
│   │   ├── 2-external-gateway.tf             # On-premises external peer gateway definitions
│   │   ├── 3-tunnels.tf                      # Redundant IPsec VPN tunnel resources
│   │   ├── 4-router-interface.tf             # Cloud Router point-to-point BGP interfaces
│   │   ├── 5-router-peer.tf                  # Cloud Router eBGP peering sessions with BFD
│   │   ├── variables.tf                      # Input variables
│   │   ├── outputs.tf                        # Gateway IPs, tunnel IDs, interfaces & peers
│   │   ├── versions.tf                       # Provider constraints
│   │   └── README.md                         # Detailed module documentation
│   ├── hierarchical-firewalls/               # Folder/Org hierarchical firewall guardrails
│   │   ├── 0-locals.tf                       # YAML parser & deterministic rule indexing
│   │   ├── 1-firewall.tf                     # Policy container resource
│   │   ├── 2-rules.tf                        # Dynamic firewall rules with Layer 4 matching
│   │   ├── 3-firewall-association.tf         # Policy association to target Folder or Org
│   │   ├── variables.tf                      # Input variables
│   │   ├── outputs.tf                        # Output definitions & rule summaries
│   │   ├── versions.tf                       # Provider constraints
│   │   └── README.md                         # Detailed module documentation
│   ├── network-peering/                      # VPC Network Peering (Bi-directional handshake)
│   │   ├── 0-locals.tf                       # YAML parser & reverse peering partitioner
│   │   ├── main.tf                           # Forward and automated reverse peering resources
│   │   ├── variables.tf                      # Input variables
│   │   ├── outputs.tf                        # Comprehensive peering state outputs & counts
│   │   ├── versions.tf                       # Provider constraints
│   │   └── README.md                         # Detailed module documentation
│   ├── private-service-connect/              # Private Service Connect (Google APIs & published services)
│   │   ├── 0-locals.tf                       # YAML parser & subnetwork self-link normalizer
│   │   ├── 1-psc-apis.tf                     # Global internal IP & PSC forwarding rule for Google APIs
│   │   ├── 2-psc-services.tf                 # Regional internal IP & PSC forwarding rules for published services
│   │   ├── variables.tf                      # Input variables
│   │   ├── outputs.tf                        # Output definitions (endpoints, IPs, counts)
│   │   ├── versions.tf                       # Provider constraints
│   │   └── README.md                         # Detailed module documentation
│   ├── shared-vpc/                           # Shared VPC cross-project attachments & subnet IAM
│   │   ├── 0-locals.tf                       # YAML parser & robot service agent derivation
│   │   ├── 1-host-project.tf                 # Host project enablement
│   │   ├── 2-service-projects.tf             # Service project dynamic attachment
│   │   ├── 3-gke-host-level-permission.tf    # GKE service agent host-level IAM permissions
│   │   ├── 4-custom-subnet-iam.tf            # Fine-grained subnet networkUser delegations
│   │   ├── variables.tf                      # Input variables
│   │   ├── outputs.tf                        # Output definitions
│   │   ├── versions.tf                       # Terraform and provider constraints
│   │   └── README.md                         # Detailed Shared VPC module documentation
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
│   ├── foundation/                           # Enterprise landing zone deployment example
│   └── network/
│       ├── basic-vpc-setup/                  # Multi-VPC hub & spoke deployment example
│       ├── shared-vpc-setup/                 # Two-stage Shared VPC cross-project setup
│       ├── firewall-setup/                   # Hierarchical firewall guardrails example
│       ├── dns-setup/                        # Private & hybrid Cloud DNS example
│       ├── peering-setup/                    # VPC Network Peering deployment example
│       ├── psc-setup/                        # Private Service Connect deployment example
│       └── vpn-setup/                        # HA Cloud VPN site-to-site deployment example
├── .gitignore                                # Git ignore rules
└── README.md                                 # Root repository documentation
```

---

## Module Catalog

| Domain | Module | Description | Directory |
|---|---|---|---|
| **Foundation** | **Resource Hierarchy & Project Factory** | Declarative GCP Landing Zone via YAML. Provisions Essential Contacts, organization Resource Tags, multi-tier folder hierarchy, projects with billing attachment, API activation, organization/folder/project IAM (with CEL conditions), custom workload service accounts, Project Deletion Liens, and Compute Engine default SA deprivileging. | [`foundation-infrastructure`](./foundation-infrastructure/) |
| **Networking** | **VPC, Subnets, BGP Router, NAT, Firewall & PSA** | End-to-end VPC networking provisioned via YAML. Supports multi-region subnets, secondary ranges for GKE, VPC flow logs, Cloud Routers with detailed BGP configuration, Cloud NAT gateways, Private Service Access (`servicenetworking.googleapis.com`), and ingress/egress firewall rules. | [`networking-infrastructure/vpc-subnet-router-nat-firewall`](./networking-infrastructure/vpc-subnet-router-nat-firewall/) |
| **Networking** | **Shared VPC (Cross-Project Subnet IAM)** | Declarative Shared VPC orchestration via YAML. Enables Host Project, attaches Service Projects, automates GKE/Compute/Cloud Run service agent permissions, and provisions least-privilege subnetwork IAM delegations. | [`networking-infrastructure/shared-vpc`](./networking-infrastructure/shared-vpc/) |
| **Networking** | **Hierarchical Firewall Policies** | Centrally managed Organization- and Folder-level security guardrails. Evaluated prior to any VPC firewall rules, enforcing universal internet port blocks (SSH/RDP), health check probes, and RFC 1918 internal communication. | [`networking-infrastructure/hierarchical-firewalls`](./networking-infrastructure/hierarchical-firewalls/) |
| **Networking** | **Cloud DNS (Private, Hybrid & Restricted APIs)** | Declarative Google Cloud DNS management via YAML. Provisions Private Authoritative Zones, Hybrid DNS Forwarding to on-premises resolvers across Cloud VPN/Interconnect, Cross-VPC Peering, and zero-egress Restricted Google APIs VIP routing (`199.36.153.4/30`). | [`networking-infrastructure/cloud-dns`](./networking-infrastructure/cloud-dns/) |
| **Networking** | **Private Service Connect (Google APIs & Published SaaS)** | Declarative Google Cloud Private Service Connect (PSC) management via YAML. Provisions global PSC endpoints for Google APIs (`all-apis`, `vpc-sc`) and regional endpoints for published third-party or producer services without VPC peering or public IPs. | [`networking-infrastructure/private-service-connect`](./networking-infrastructure/private-service-connect/) |
| **Networking** | **VPC Network Peering (Automated Bi-directional Handshake)** | Declarative Google Cloud VPC Network Peering via YAML. Provisions bi-directional or uni-directional peering connections with automatic reverse peering creation, route exchange controls (custom routes, public subnets), and dependency ordering. | [`networking-infrastructure/network-peering`](./networking-infrastructure/network-peering/) |
| **Networking** | **High Availability (HA) Cloud VPN (99.99% SLA)** | Declarative Google Cloud HA VPN management via YAML. Provisions dual-interface gateways, external on-premises peer gateways, redundant IPsec tunnels, Cloud Router interfaces, and dynamic eBGP sessions with BFD support. | [`networking-infrastructure/ha-cloud-vpn`](./networking-infrastructure/ha-cloud-vpn/) |

---

## Quick Examples

### Example 1: Foundation Infrastructure & Project Factory

```hcl
module "foundation" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//foundation-infrastructure?ref=main"
  yaml_config_path = "${path.module}/hierarchy.yaml"
}
```

---

### Example 2: Core Networking & Shared VPC

```hcl
module "networking" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/vpc-subnet-router-nat-firewall?ref=main"
  config_file_path = "${path.module}/network-config.yaml"
}

module "shared_vpc" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/shared-vpc?ref=main"
  yaml_config_path = "${path.module}/shared_vpc.yaml"

  depends_on = [module.networking]
}
```

---

### Example 3: Hierarchical Firewall Guardrails

```hcl
module "hierarchical_firewalls" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/hierarchical-firewalls?ref=main"
  yaml_config_path = "${path.module}/firewalls.yaml"
}
```

---

### Example 4: Enterprise Cloud DNS Management

#### 1. Define DNS zones and records in `dns.yaml`:

```yaml
project_id: "yuvaraj-internal-project"

zones:
  - name: "internal-corp"
    dns_name: "internal.mycompany."
    type: "private"
    records:
      - name: "api"
        type: "A"
        ttl: 300
        rrdatas: ["10.0.0.50", "10.0.0.51"]

  - name: "onprem-forwarding"
    dns_name: "onprem.mycompany."
    type: "forwarding"
    forwarding_path: "private"
    target_name_servers: ["192.168.1.10", "192.168.1.11"]

  - name: "googleapis-restricted"
    dns_name: "googleapis.com."
    type: "private"
    records:
      - name: "restricted"
        type: "A"
        rrdatas: ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
      - name: "*"
        type: "CNAME"
        rrdatas: ["restricted.googleapis.com."]
```

#### 2. Instantiate the Cloud DNS module in your `main.tf`:

```hcl
module "cloud_dns" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/cloud-dns?ref=main"
  yaml_config_path  = "${path.module}/dns.yaml"
  network_self_link = module.networking.vpcs["platform-foundation-vpc"].self_link
}
```

---

### Example 5: Private Service Connect (PSC)

#### 1. Define PSC endpoints in `psc.yaml`:

```yaml
project_id: "yuvaraj-internal-project"

# Global PSC Endpoint for Google APIs
google_apis:
  - name: "psc-google-apis"
    ip_address: "10.0.100.10"
    target: "all-apis"

# Regional PSC Endpoints for Published Third-Party / Producer SaaS
service_attachments:
  - name: "psc-analytics-saas"
    region: "asia-south1"
    subnetwork: "psc-demo-subnet"
    ip_address: "10.0.1.200"
    target_service_attachment: "projects/producer-corp/regions/asia-south1/serviceAttachments/analytics-service"
```

#### 2. Instantiate the Private Service Connect module in your `main.tf`:

```hcl
module "psc" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/private-service-connect?ref=main"
  yaml_config_path  = "${path.module}/psc.yaml"
  network_self_link = module.networking.vpcs["platform-foundation-vpc"].self_link
}
```

---

### Example 6: VPC Network Peering (Automated Bi-directional Handshake)

#### 1. Define Peering Topology in `peering.yaml`:

```yaml
peerings:
  - name: "peering-hub-to-spoke"
    peer_network_self_link: "projects/yuvaraj-internal-project/global/networks/peering-demo-spoke-vpc"
    auto_create_reverse_peering: true # Creates return peering automatically for instant ACTIVE status
    export_custom_routes: true       # Export custom routes to peer
    import_custom_routes: false
```

#### 2. Instantiate the VPC Peering module in your `main.tf`:

```hcl
module "vpc_peering" {
  source                  = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/network-peering?ref=main"
  yaml_config_path        = "${path.module}/peering.yaml"
  local_network_self_link = module.networking.vpcs["hub-vpc"].self_link
}
```

---

### Example 7: High Availability (HA) Cloud VPN (99.99% SLA)

#### 1. Define HA VPN Gateways, Tunnels, and BGP in `vpn.yaml`:

```yaml
project_id: "yuvaraj-internal-project"
default_region: "asia-south1"
default_router_name: "cr-landing-zone-main"

gateways:
  - name: "ha-vpn-onprem-dc"
    peer_gateway:
      name: "peer-onprem-cisco-asa"
      redundancy_type: "TWO_IPS_REDUNDANCY"
      interfaces:
        - id: 0
          ip_address: "203.0.113.10"
        - id: 1
          ip_address: "203.0.113.11"
    tunnels:
      - name: "tunnel-0"
        vpn_gateway_interface: 0
        peer_external_gateway_interface: 0
        shared_secret: "C0rporateVpnSecretKey2026!#"
        bgp_session:
          router_interface_ip: "169.254.0.1/30"
          peer_ip_address: "169.254.0.2"
          peer_asn: 65001
      - name: "tunnel-1"
        vpn_gateway_interface: 1
        peer_external_gateway_interface: 1
        shared_secret: "C0rporateVpnSecretKey2026!#"
        bgp_session:
          router_interface_ip: "169.254.1.1/30"
          peer_ip_address: "169.254.1.2"
          peer_asn: 65001
```

#### 2. Instantiate the HA Cloud VPN module in your `main.tf`:

```hcl
module "ha_vpn" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/ha-cloud-vpn?ref=main"
  yaml_config_path  = "${path.module}/vpn.yaml"
  network_self_link = module.networking.vpcs["platform-foundation-vpc"].self_link
  router_name       = "cr-landing-zone-main"
}
```

---

## Prerequisites

1. **Terraform CLI**: Version `>= 1.5.0`
2. **Google Cloud SDK (`gcloud`)**: Installed and authenticated (`gcloud auth application-default login`)
3. **Required IAM Permissions**:
   - **For Foundation**: `roles/resourcemanager.organizationAdmin`, `roles/resourcemanager.folderAdmin`, `roles/billing.user` (or `roles/billing.admin`), `roles/resourcemanager.tagAdmin`, `roles/essentialcontacts.admin`, and `roles/resourcemanager.lienModifier`
   - **For Networking, PSC, VPC Peering & HA VPN**: `roles/compute.networkAdmin`, `roles/compute.securityAdmin`, and `roles/servicenetworking.networksAdmin`
   - **For Shared VPC**: `roles/compute.xpnAdmin` (at Folder/Org level) and `roles/resourcemanager.projectIamAdmin` (Host project)
   - **For Hierarchical Firewalls**: `roles/compute.orgFirewallPolicyAdmin` or `roles/compute.orgSecurityPolicyAdmin` (at Folder/Org level)
   - **For Cloud DNS**: `roles/dns.admin`
4. **Required GCP APIs Enabled** (on administrative/seed project):
   - `cloudresourcemanager.googleapis.com`
   - `serviceusage.googleapis.com`
   - `cloudbilling.googleapis.com`
   - `iam.googleapis.com`
   - `essentialcontacts.googleapis.com`
   - `compute.googleapis.com`
   - `servicenetworking.googleapis.com`
   - `dns.googleapis.com`

---

## License

This repository is distributed under the [MIT License](LICENSE).
