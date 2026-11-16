# Google Cloud High Availability (HA) Cloud VPN Custom Module

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Declarative YAML](https://img.shields.io/badge/Config-Declarative%20YAML-orange.svg)](#declarative-yaml-schema)
[![SLA](https://img.shields.io/badge/SLA-99.99%25%20High%20Availability-success.svg)](#architecture-overview)

This module provides a production-grade, declarative Terraform implementation for **Google Cloud High Availability (HA) Cloud VPN** driven by structured YAML configurations.

HA Cloud VPN establishes resilient, site-to-site IPsec VPN connectivity between your Google Cloud VPC networks and on-premises data centers or third-party cloud environments (AWS, Azure) backed by a **99.99% service availability SLA**.

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
- [On-Premises Firewall Requirements](#on-premises-firewall-requirements)
- [Engineering & Resilience Highlights](#engineering--resilience-highlights)

---

## Architecture Overview

Google Cloud HA VPN provides two interfaces (Interface 0 and Interface 1) with separate public IP addresses. When paired with an on-premises peer gateway featuring dual public WAN IPs, it creates a fully redundant, dual-tunnel active-active or active-passive mesh:

```mermaid
flowchart TD
    subgraph GCP["Google Cloud (Region: asia-south1)"]
        subgraph VPC["Base VPC Network"]
            CR["Cloud Router (cr-vpn-demo)<br/>ASN: 65000"]
            
            subgraph HA_GW["HA VPN Gateway (ha-vpn-onprem-dc)"]
                IF0["GCP Interface 0<br/>Public IP (Interface 0)"]
                IF1["GCP Interface 1<br/>Public IP (Interface 1)"]
            end
            
            BGP0["BGP Interface 0<br/>169.254.0.1/30"]
            BGP1["BGP Interface 1<br/>169.254.1.1/30"]
        end
    end

    subgraph ONPREM["Corporate On-Premises Data Center"]
        subgraph PEER_GW["External Peer Gateway (Cisco ASA / Fortinet / Palo Alto)"]
            P_IF0["Peer Interface 0<br/>WAN IP 0: 203.0.113.10"]
            P_IF1["Peer Interface 1<br/>WAN IP 1: 203.0.113.11"]
        end
        
        ONPREM_ROUTER["On-Prem BGP Router<br/>ASN: 65001"]
        P_BGP0["Peer BGP: 169.254.0.2"]
        P_BGP1["Peer BGP: 169.254.1.2"]
    end

    IF0 <==>|IPsec Tunnel 0 (IKEv2)| P_IF0
    IF1 <==>|IPsec Tunnel 1 (IKEv2)| P_IF1

    CR --- BGP0
    CR --- BGP1

    BGP0 <-->|eBGP Session 0 (MED: 100)| P_BGP0
    BGP1 <-->|eBGP Session 1 (MED: 100)| P_BGP1

    P_BGP0 --- ONPREM_ROUTER
    P_BGP1 --- ONPREM_ROUTER
```

---

## Key Features & Capabilities

1. **99.99% Availability SLA**:
   - Manages dual-interface HA VPN gateways with paired IPsec tunnels mapped to independent external peer interfaces.
2. **Dynamic BGP Routing (eBGP)**:
   - Eliminates fragile static route maintenance by automating Cloud Router interfaces and BGP peer sessions.
   - Supports Multi-Exit Discriminator (MED) route priorities for deterministic active/active or active/passive failover.
3. **Sub-Second Failover via BFD**:
   - Optional Bidirectional Forwarding Detection (BFD) integration for microsecond link-down detection and BGP reconvergence.
4. **Decoupled External Peer Gateways**:
   - Automatically deduplicates and provisions `google_compute_external_vpn_gateway` devices (supporting `TWO_IPS_REDUNDANCY`, `SINGLE_IP_INTERNALLY_REDUNDANT`, or `FOUR_IPS_REDUNDANCY`).
5. **Deterministic Pipeline**:
   - Strict resource chaining (`gateway -> external_gateway -> tunnel -> interface -> peer`) guarantees zero race conditions during provisioning.

---

## Directory Structure

```
networking-infrastructure/ha-cloud-vpn/
├── 0-locals.tf            # YAML parser, gateway mapping & tunnel flattening
├── 1-vpn-gateway.tf       # Google Cloud HA VPN Gateway resources
├── 2-external-gateway.tf   # External VPN peer gateway definitions
├── 3-tunnels.tf           # Redundant IPsec VPN tunnel resources
├── 4-router-interface.tf  # Cloud Router point-to-point BGP interfaces
├── 5-router-peer.tf       # Cloud Router eBGP peering sessions with BFD
├── variables.tf           # Input variables with fallback logic
├── outputs.tf             # Gateway IPs, tunnel IDs, interfaces, and peers
├── versions.tf            # Terraform and Google provider constraints
└── README.md              # Detailed module documentation
```

---

## Prerequisites & IAM Permissions

- **Compute Network Admin**: `roles/compute.networkAdmin` on the target project to provision gateways, tunnels, router interfaces, and BGP peers.
- **Compute Security Admin**: `roles/compute.securityAdmin` to allow cross-premises firewall rules.
- **Pre-existing Cloud Router**: An active Cloud Router must exist in the same region and VPC before establishing BGP sessions.

---

## Declarative YAML Schema

Create a YAML configuration file (e.g. `vpn.yaml`):

```yaml
project_id: "yuvaraj-internal-project"
default_region: "asia-south1"
default_router_name: "cr-vpn-demo"

# ------------------------------------------------------------------------------
# HA VPN GATEWAYS & REDUNDANT TUNNELS
# ------------------------------------------------------------------------------
gateways:
  - name: "ha-vpn-onprem-dc"
    region: "asia-south1"
    router_name: "cr-vpn-demo"
    description: "HA VPN connection to Corporate On-Premises Data Center"

    # External Peer Gateway (On-Premises Firewall / Router)
    peer_gateway:
      name: "peer-onprem-cisco-asa"
      redundancy_type: "TWO_IPS_REDUNDANCY" # Options: TWO_IPS_REDUNDANCY, SINGLE_IP_INTERNALLY_REDUNDANT, FOUR_IPS_REDUNDANCY
      interfaces:
        - id: 0
          ip_address: "203.0.113.10" # On-Prem primary WAN public IP
        - id: 1
          ip_address: "203.0.113.11" # On-Prem secondary WAN public IP

    # Redundant Active-Active Tunnels
    tunnels:
      # Tunnel 0: GCP Interface 0 -> Peer Interface 0
      - name: "tunnel-0"
        vpn_gateway_interface: 0
        peer_external_gateway_interface: 0
        shared_secret: "C0rporateVpnSecretKey2026!#"
        bgp_session:
          router_interface_ip: "169.254.0.1/30" # GCP link-local BGP IP
          peer_ip_address: "169.254.0.2"       # Peer link-local BGP IP
          peer_asn: 65001                      # On-prem BGP ASN
          advertised_route_priority: 100

      # Tunnel 1: GCP Interface 1 -> Peer Interface 1
      - name: "tunnel-1"
        vpn_gateway_interface: 1
        peer_external_gateway_interface: 1
        shared_secret: "C0rporateVpnSecretKey2026!#"
        bgp_session:
          router_interface_ip: "169.254.1.1/30" # GCP link-local BGP IP
          peer_ip_address: "169.254.1.2"       # Peer link-local BGP IP
          peer_asn: 65001                      # On-prem BGP ASN
          advertised_route_priority: 100
```

### YAML Schema Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `project_id` | string | No | GCP Project ID (can also be passed via variable). |
| `default_region` | string | No | Default region for gateways and tunnels (e.g. `asia-south1`). |
| `default_router_name` | string | No | Default Cloud Router to attach BGP interfaces to. |
| `gateways[].name` | string | **Yes** | Unique name for the GCP HA VPN Gateway. |
| `gateways[].region` | string | No | Region override for this specific gateway. |
| `gateways[].router_name` | string | No | Cloud Router override for this specific gateway. |
| `gateways[].peer_gateway.name` | string | **Yes** | Unique name for the remote peer gateway device. |
| `gateways[].peer_gateway.redundancy_type` | string | No | `TWO_IPS_REDUNDANCY`, `SINGLE_IP_INTERNALLY_REDUNDANT`, or `FOUR_IPS_REDUNDANCY`. |
| `gateways[].peer_gateway.interfaces[].id` | number | **Yes** | Numeric interface ID (0, 1, 2, or 3). |
| `gateways[].peer_gateway.interfaces[].ip_address` | string | **Yes** | Public WAN IP of the on-premises router interface. |
| `gateways[].tunnels[].name` | string | **Yes** | Tunnel suffix name (e.g. `tunnel-0`). |
| `gateways[].tunnels[].vpn_gateway_interface` | number | **Yes** | GCP interface index (`0` or `1`). |
| `gateways[].tunnels[].peer_external_gateway_interface` | number | **Yes** | Peer gateway interface index (`0`, `1`, etc.). |
| `gateways[].tunnels[].shared_secret` | string | **Yes** | Pre-shared key (PSK) for IKE authentication. |
| `gateways[].tunnels[].bgp_session.router_interface_ip` | string | **Yes** | GCP link-local CIDR (e.g. `169.254.0.1/30`). |
| `gateways[].tunnels[].bgp_session.peer_ip_address` | string | **Yes** | Peer link-local IP (e.g. `169.254.0.2`). |
| `gateways[].tunnels[].bgp_session.peer_asn` | number | **Yes** | Remote BGP Autonomous System Number. |
| `gateways[].tunnels[].bgp_session.advertised_route_priority` | number | No | BGP MED route priority (Default: `100`). |

---

## Usage Examples

```hcl
module "ha_vpn" {
  source            = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//networking-infrastructure/ha-cloud-vpn?ref=main"
  yaml_config_path  = "${path.module}/vpn.yaml"
  network_self_link = module.networking.vpcs["platform-vpc"].self_link
}
```

---

## Module Inputs

| Name | Type | Description | Default | Required |
|---|---|---|---|---|
| `yaml_config_path` | `string` | Path to the YAML configuration file defining the HA VPN topology. | `"./vpn.yaml"` | No |
| `network_self_link` | `string` | Self-link or URI of the target VPC network. | `""` | No |
| `project_id` | `string` | Target GCP project ID (falls back to YAML if empty). | `""` | No |
| `default_region` | `string` | Default GCP region for gateways and tunnels. | `""` | No |
| `router_name` | `string` | Target Cloud Router name to attach interfaces and peers. | `""` | No |

---

## Module Outputs

| Name | Type | Description |
|---|---|---|
| `gateways` | `map(object)` | Provisioned HA VPN Gateways including interface public IP addresses. |
| `gateway_public_ips` | `map(object)` | GCP HA VPN Gateway public IPs (`interface_0_ip`, `interface_1_ip`) for on-prem firewall whitelisting. |
| `external_gateways` | `map(object)` | Registered external peer gateways and their interface IP configurations. |
| `tunnels` | `map(object)` | Provisioned IPsec VPN tunnels and operational metadata. |
| `tunnel_ids` | `map(string)` | Lookup map of tunnel names to their resource IDs. |
| `router_interfaces` | `map(object)` | Cloud Router point-to-point BGP interfaces. |
| `router_peers` | `map(object)` | Configured eBGP peering sessions with remote ASNs. |
| `total_gateways_count` | `number` | Total number of HA VPN Gateways created. |
| `total_tunnels_count` | `number` | Total number of IPsec VPN tunnels created. |
| `total_bgp_peers_count` | `number` | Total number of BGP peer sessions created. |

---

## On-Premises Firewall Requirements

For IPsec negotiation and encrypted traffic flow, ensure your on-premises edge firewalls permit the following inbound/outbound protocols between the on-premises WAN IPs and the GCP Gateway Public IPs (retrieved from `gateway_public_ips` output):

1. **IKE (Phase 1 & 2 Negotiations)**: UDP port `500`
2. **NAT-Traversal (NAT-T)**: UDP port `4500`
3. **Encapsulating Security Payload (ESP)**: IP protocol `50`

---

## Engineering & Resilience Highlights

- **99.99% Availability Guarantee**: Using two tunnels across both interfaces connected to redundant on-prem endpoints guarantees Google Cloud's 99.99% SLA.
- **Link-Local IP Range Isolation**: Uses dedicated `/30` subnets in the `169.254.0.0/16` RFC 3927 link-local range for BGP peering to avoid polluting private enterprise CIDRs.
- **Strict Ordering**: Cloud Router BGP interfaces depend on the established VPN tunnel, and BGP peers depend on the created interface, preventing transient API errors during deployment.
