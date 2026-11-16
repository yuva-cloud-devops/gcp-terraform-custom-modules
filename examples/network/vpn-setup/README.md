# High Availability (HA) Cloud VPN Example

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Declarative YAML](https://img.shields.io/badge/Config-vpn.yaml-orange.svg)](#declarative-vpn-topology)
[![SLA](https://img.shields.io/badge/SLA-99.99%25%20High%20Availability-success.svg)](#architecture-overview)

This example demonstrates how to deploy an end-to-end, enterprise **Google Cloud High Availability (HA) Cloud VPN** solution using our declarative [`networking-infrastructure/ha-cloud-vpn`](../../../networking-infrastructure/ha-cloud-vpn) custom module.

The deployment creates a self-contained environment with a **Base VPC**, a **Workload Subnet**, a **Cloud Router** running dynamic BGP (ASN 65000), an **HA VPN Gateway** with dual interfaces, an **External Peer Gateway** representing an on-premises Cisco/Palo Alto firewall, and **dual IPsec tunnels** with eBGP peering sessions to guarantee **99.99% service availability**.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph GCP["Google Cloud (Region: asia-south1)"]
        subgraph VPC["vpn-demo-vpc"]
            SUBNET["vpn-demo-subnet (10.50.1.0/24)"]
            CR["Cloud Router: cr-vpn-demo (ASN: 65000)"]
            
            subgraph HA_GW["HA VPN Gateway: ha-vpn-onprem-dc"]
                IF0["GCP Interface 0<br/>Public IP (Interface 0)"]
                IF1["GCP Interface 1<br/>Public IP (Interface 1)"]
            end
            
            BGP0["BGP Interface 0<br/>169.254.0.1/30"]
            BGP1["BGP Interface 1<br/>169.254.1.1/30"]
        end
    end

    subgraph ONPREM["Corporate On-Premises Data Center"]
        subgraph PEER_GW["External Peer Gateway: peer-onprem-cisco-asa"]
            P_IF0["Peer Interface 0<br/>WAN IP: 203.0.113.10"]
            P_IF1["Peer Interface 1<br/>WAN IP: 203.0.113.11"]
        end
        
        ONPREM_ROUTER["On-Prem BGP Router (ASN: 65001)"]
        P_BGP0["Peer BGP: 169.254.0.2"]
        P_BGP1["Peer BGP: 169.254.1.2"]
    end

    IF0 <==>|IPsec Tunnel 0 (IKEv2)| P_IF0
    IF1 <==>|IPsec Tunnel 1 (IKEv2)| P_IF1

    CR --- BGP0
    CR --- BGP1

    BGP0 <-->|eBGP Session 0| P_BGP0
    BGP1 <-->|eBGP Session 1| P_BGP1

    P_BGP0 --- ONPREM_ROUTER
    P_BGP1 --- ONPREM_ROUTER
```

---

## Files in this Directory

| File | Purpose |
|---|---|
| [`main.tf`](./main.tf) | Provisions the VPC, Subnet, Cloud Router, and calls the `ha-cloud-vpn` module. |
| [`vpn.yaml`](./vpn.yaml) | Declarative configuration defining gateways, peer devices, IPsec tunnels, and BGP parameters. |
| [`provider.tf`](./provider.tf) | Configures the Google provider and Terraform version constraints. |
| [`outputs.tf`](./outputs.tf) | Exports gateway public IPs, tunnel IDs, router interfaces, and BGP peering states. |
| [`README.md`](./README.md) | Architectural documentation, walkthrough, and verification commands. |

---

## Declarative VPN Topology (`vpn.yaml`)

```yaml
project_id: "yuvaraj-internal-project"
default_region: "asia-south1"
default_router_name: "cr-vpn-demo"

gateways:
  - name: "ha-vpn-onprem-dc"
    region: "asia-south1"
    router_name: "cr-vpn-demo"
    description: "HA VPN connection to Corporate On-Premises Data Center"

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
          advertised_route_priority: 100

      - name: "tunnel-1"
        vpn_gateway_interface: 1
        peer_external_gateway_interface: 1
        shared_secret: "C0rporateVpnSecretKey2026!#"
        bgp_session:
          router_interface_ip: "169.254.1.1/30"
          peer_ip_address: "169.254.1.2"
          peer_asn: 65001
          advertised_route_priority: 100
```

---

## Deployment Guide

### Prerequisites

1. **Google Cloud SDK (`gcloud`)** installed and authenticated:
   ```bash
   gcloud auth application-default login
   ```
2. **Terraform CLI (`>= 1.5.0`)** installed.
3. Target project permissions: `roles/compute.networkAdmin` and `roles/compute.securityAdmin`.

### Step-by-Step Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Validate Configuration**:
   ```bash
   terraform validate
   ```

3. **Review Execution Plan**:
   ```bash
   terraform plan
   ```

4. **Apply Infrastructure**:
   ```bash
   terraform apply
   ```

---

## On-Premises Firewall Configuration

Once Terraform finishes applying, retrieve the allocated GCP HA VPN public IP addresses using:

```bash
terraform output gateway_public_ips
```

Configure your on-premises edge firewalls to permit the following traffic between your on-prem WAN IPs (`203.0.113.10`, `203.0.113.11`) and the GCP gateway interface IPs:

- **UDP Port 500**: Internet Key Exchange (IKE) Phase 1 and 2
- **UDP Port 4500**: NAT Traversal (NAT-T)
- **IP Protocol 50**: Encapsulating Security Payload (ESP)

---

## Verification Commands

After applying, verify that the VPN gateways, tunnels, and BGP routing sessions are operational:

### 1. Check HA VPN Gateway Status
```bash
gcloud compute vpn-gateways list --filter="name:ha-vpn-onprem-dc"
```

### 2. Check IPsec Tunnel States
```bash
gcloud compute vpn-tunnels list --filter="vpnGateway:ha-vpn-onprem-dc"
```

### 3. Check Cloud Router BGP Peering Session Status
```bash
gcloud compute routers get-status cr-vpn-demo --region=asia-south1
```

Expected output shows `BGP_SESSION_ESTABLISHED` and received route prefixes from the on-premises ASN `65001`.

---

## Cleanup

To tear down all resources provisioned by this example:

```bash
terraform destroy
```
