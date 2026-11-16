# Google Cloud VPC Network Peering Custom Module

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Declarative YAML](https://img.shields.io/badge/Config-Declarative%20YAML-orange.svg)](#declarative-yaml-schema)
[![Enterprise Ready](https://img.shields.io/badge/Architecture-VPC%20Network%20Peering-success.svg)](#architecture-overview)

This module provides an enterprise-grade, declarative Terraform implementation for **Google Cloud VPC Network Peering** configured via structured YAML files.

VPC Network Peering enables direct, private RFC 1918 IPv4 and IPv6 connectivity across different Virtual Private Clouds (VPCs)—whether in the same project, across different projects, or across different Google Cloud organizations—without traversing the public internet, using intermediate VPN gateways, or incurring data routing latency.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Key Features & Capabilities](#key-features--capabilities)
- [Directory Structure](#directory-structure)
- [Prerequisites & IAM Permissions](#prerequisites--iam-permissions)
- [Declarative YAML Schema](#declarative-yaml-schema)
- [Usage Examples](#usage-examples)
- [Module Inputs](#module-inputs)
- [Module Outputs](#module-outputs)
- [Bi-directional Handshake Mechanics](#bi-directional-handshake-mechanics)
- [Engineering & Resilience Highlights](#engineering--resilience-highlights)
- [VPC Peering vs Other Connectivity Models](#vpc-peering-vs-other-connectivity-models)

---

## Architecture Overview

```mermaid
flowchart LR
    subgraph LOCAL["Local Base VPC (e.g. Hub / Shared VPC)"]
        LOCAL_VM["Compute Engine / GKE Pod<br/>(10.10.1.0/24)"]
        PEER_A["Peering Resource A<br/>name: peering-hub-to-spoke"]
    end

    subgraph REMOTE["Remote Peer VPC (e.g. Spoke / Analytics VPC)"]
        PEER_B["Reverse Peering Resource B<br/>name: peering-hub-to-spoke-reverse"]
        REMOTE_VM["Analytics Workload<br/>(10.20.1.0/24)"]
    end

    subgraph VENDOR["External Vendor / Partner VPC"]
        VENDOR_PEER["Vendor Managed Peering<br/>(Partner administers remote side)"]
        VENDOR_VM["Vendor Service"]
    end

    LOCAL_VM <-->|Internal Google Andromeda SDN| REMOTE_VM
    PEER_A <==>|Bi-directional Handshake (ACTIVE)| PEER_B
    PEER_A -.->|Uni-directional Setup (INACTIVE until vendor accepts)| VENDOR_PEER
```

---

## Key Features & Capabilities

1. **Automated Bi-directional Peering Handshake**:
   - Google Cloud VPC Peering requires a mutual handshake: Network A must peer to Network B, and Network B must peer to Network A before traffic can flow (`ACTIVE` state).
   - Setting `auto_create_reverse_peering: true` automatically creates the reverse connection in the peer project/VPC, eliminating multi-phase manual setups.
2. **Fine-Grained Route Control**:
   - **Custom Route Exchange**: Export and import static or dynamically learned BGP routes from Cloud Routers across peering boundaries.
   - **Public IP Subnet Routes**: Control whether subnets with public IPv4 addresses are advertised to or imported from the peer network.
   - **Automated Route Inversion**: For reverse peerings, route export and import flags are automatically inverted for symmetric traffic flow unless custom overrides are specified.
3. **Decoupled Architecture & Dynamic Overrides**:
   - Accepts peer network self-links either statically via YAML or dynamically via `peer_network_overrides` from upstream Terraform resources.
4. **Race Condition Prevention**:
   - Enforces explicit Terraform dependencies between forward and reverse peerings to prevent Google Cloud API concurrency errors when modifying network metadata.

---

## Directory Structure

```
networking-infrastructure/network-peering/
├── 0-locals.tf        # YAML parser, self-link normalization & reverse peering partitioner
├── main.tf            # Forward and automated reverse peering compute resources
├── outputs.tf         # Comprehensive outputs (states, IDs, route settings, counts)
├── variables.tf       # Input variables with sensible defaults
├── versions.tf        # Provider constraints (Terraform >= 1.5.0, Google >= 5.0.0)
└── README.md          # Module documentation
```

---

## Prerequisites & IAM Permissions

To manage VPC Network Peering, the executing principal (Service Account or User) requires the following permissions:

- **Compute Network Admin**: `roles/compute.networkAdmin` on the host/parent project of **both** the local VPC and the remote peer VPC (when `auto_create_reverse_peering` is `true`).
- **Compute Security Admin**: `roles/compute.securityAdmin` on both projects to allow firewall traffic between peered VPCs.

---

## Declarative YAML Schema

Create a YAML configuration file (e.g. `peering.yaml`):

```yaml
# ==============================================================================
# VPC NETWORK PEERINGS CONFIGURATION
# ==============================================================================
# Optional fallback for local network self link (can also be passed via variable)
local_network_self_link: ""

peerings:
  # Scenario 1: Bi-directional peering (Both sides created automatically)
  # Ideal for Hub-to-Spoke, Shared VPC to Analytics VPC within your organization
  - name: "peering-shared-to-analytics"
    peer_network_self_link: "projects/analytics-prod-123/global/networks/vpc-analytics"
    auto_create_reverse_peering: true          # Automatically provision return peering
    export_custom_routes: true                 # Export static/BGP routes to peer
    import_custom_routes: false                # Do not import custom routes from peer
    export_subnet_routes_with_public_ip: false # Do not advertise public subnets
    import_subnet_routes_with_public_ip: false # Do not import public subnets

  # Scenario 2: Uni-directional peering (Remote side managed by partner or vendor)
  # The peering will remain INACTIVE until the vendor configures their return peering
  - name: "peering-shared-to-vendor"
    peer_network_self_link: "projects/vendor-corp-net/global/networks/vpc-vendor"
    auto_create_reverse_peering: false         # Vendor administers their own side
    export_custom_routes: false
    import_custom_routes: true                 # Import custom routes published by vendor
    export_subnet_routes_with_public_ip: false
    import_subnet_routes_with_public_ip: false
```

### YAML Attribute Reference

| Field | Type | Required | Description | Default |
|---|---|---|---|---|
| `name` | string | **Yes** | Unique identifier for the peering connection. | - |
| `peer_network_self_link` | string | **Yes** | Fully qualified URI or self-link of the peer VPC network. | - |
| `auto_create_reverse_peering` | bool | No | Automatically provisions the return peering resource in the peer network. | `false` |
| `export_custom_routes` | bool | No | Export static and dynamic custom routes to the peer network. | `false` |
| `import_custom_routes` | bool | No | Import static and dynamic custom routes from the peer network. | `false` |
| `export_subnet_routes_with_public_ip` | bool | No | Export subnets configured with public IPv4 ranges. | `false` |
| `import_subnet_routes_with_public_ip` | bool | No | Import subnets configured with public IPv4 ranges. | `false` |
| `stack_type` | string | No | IP stack type for peering: `IPV4_ONLY` or `IPV4_IPV6`. | `IPV4_ONLY` |
| `reverse_name` | string | No | Custom name for the reverse peering connection. | `"<name>-reverse"` |
| `reverse_export_custom_routes` | bool | No | Custom route export flag for the reverse peering. | Inverted from `import_custom_routes` |
| `reverse_import_custom_routes` | bool | No | Custom route import flag for the reverse peering. | Inverted from `export_custom_routes` |

---

## Usage Examples

### 1. Basic YAML-Driven Peering

```hcl
module "vpc_peering" {
  source                  = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/network-peering?ref=main"
  yaml_config_path        = "${path.module}/peering.yaml"
  local_network_self_link = module.networking.vpcs["hub-vpc"].self_link
}
```

### 2. Peering with Dynamic Network Overrides

When peer networks are provisioned within the same Terraform execution or remote state:

```hcl
module "vpc_peering" {
  source                  = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/network-peering?ref=main"
  yaml_config_path        = "${path.module}/peering.yaml"
  local_network_self_link = google_compute_network.hub_vpc.self_link

  peer_network_overrides = {
    "peering-shared-to-analytics" = google_compute_network.analytics_vpc.self_link
  }
}
```

---

## Module Inputs

| Name | Type | Description | Default | Required |
|---|---|---|---|---|
| `yaml_config_path` | `string` | File path to the YAML configuration defining peering configurations. | `"./peering.yaml"` | No |
| `local_network_self_link` | `string` | Self-link or URI of the local base VPC network initiating the peering connection. | `""` | No |
| `peer_network_overrides` | `map(string)` | Map of peering names to peer network self-links to override values declared in the YAML. | `{}` | No |

---

## Module Outputs

| Name | Type | Description |
|---|---|---|
| `local_peerings` | `map(object)` | Detailed map of all forward peering connections (ID, name, network, peer, states, routes). |
| `reverse_peerings` | `map(object)` | Detailed map of all automated reverse peering connections. |
| `all_peerings` | `map(object)` | Unified map combining both forward and reverse peerings with direction metadata. |
| `peering_states` | `map(string)` | Key-value mapping of peering names to their operational state (`ACTIVE`, `INACTIVE`). |
| `total_local_peerings` | `number` | Count of forward peering connections provisioned. |
| `total_reverse_peerings` | `number` | Count of reverse peering connections provisioned. |
| `total_peerings_count` | `number` | Total number of peering resources managed by this module. |

---

## Bi-directional Handshake Mechanics

Google Cloud VPC Network Peering requires symmetric intent:

```
Step 1: Network A creates peering to Network B  -->  Status: INACTIVE
Step 2: Network B creates peering to Network A  -->  Status: ACTIVE (Traffic flows!)
```

When `auto_create_reverse_peering` is set to `true`:
1. Terraform creates `google_compute_network_peering.local_to_peer` (Network A -> Network B).
2. Through explicit `depends_on`, Terraform subsequently creates `google_compute_network_peering.peer_to_local` (Network B -> Network A).
3. Both peerings immediately achieve the `ACTIVE` state without manual intervention.

---

## Engineering & Resilience Highlights

- **Dependency Sequencing**: `depends_on = [google_compute_network_peering.local_to_peer]` prevents concurrent modification conflicts against Google Cloud VPC metadata.
- **Symmetric Route Inversion**: Automatically flips export/import flags for reverse peerings, avoiding unidirectional routing blackholes.
- **Subnet Overlap Verification**: Before provisioning peering in production, ensure that the IP ranges of the peered VPCs do not overlap. GCP will fail peering establishment if overlapping CIDRs exist.
- **Transitivity Rule**: VPC Peering is **strictly non-transitive**. If Network A peers with Network B, and Network B peers with Network C, Network A cannot reach Network C through Network B. Workloads requiring transit routing must use Cloud VPN or intermediate Network Virtual Appliances (NVAs).

---

## VPC Peering vs Other Connectivity Models

| Feature | VPC Network Peering | Private Service Connect (PSC) | Cloud VPN / HA VPN | Cloud Interconnect |
|---|---|---|---|---|
| **Egress Bandwidth Limits** | Full VPC fabric line rate (Up to 100 Gbps) | Full VPC fabric rate | Up to 3 Gbps per tunnel | 10 Gbps – 100 Gbps |
| **Data Transfer Pricing** | Standard inter-zone/inter-region egress | Minimal endpoint processing fee | Standard egress + VPN hourly | Interconnect port + low egress |
| **CIDR Overlaps Allowed?** | ❌ Strictly forbidden |  Allowed (1:1 NAT / SNAT) | ❌ Requires Cloud NAT | ❌ Strictly forbidden |
| **Transitive Routing?** | ❌ No | ❌ No |  Yes (via BGP) |  Yes (via BGP) |
| **Configuration Model** | Bi-directional peering handshake | Unidirectional endpoint to attachment | IPsec IKE tunnels + BGP | Dedicated physical circuit |
