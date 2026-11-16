# VPC Network Peering Example

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Declarative YAML](https://img.shields.io/badge/Config-peering.yaml-orange.svg)](#declarative-peering-topology)
[![Status](https://img.shields.io/badge/State-Bi--Directional%20Active-success.svg)](#bidirectional-handshake-mechanics)

This example demonstrates how to deploy and manage production-grade **Google Cloud VPC Network Peering** connections using our declarative [`networking-infrastructure/network-peering`](../../../networking-infrastructure/network-peering) custom module.

The deployment creates a self-contained environment with a **Hub VPC** and a **Spoke VPC**, dynamically connecting them via bi-directional peering while configuring custom route propagation flags.

---

## Architecture Overview

```mermaid
flowchart LR
    subgraph HUB["Hub VPC (peering-demo-hub-vpc)"]
        HUB_SUBNET["Hub Subnet: 10.10.1.0/24<br/>Region: asia-south1"]
        PEER_FORWARD["Peering: peering-hub-to-spoke<br/>export_custom_routes: true"]
    end

    subgraph SPOKE["Spoke VPC (peering-demo-spoke-vpc)"]
        PEER_REVERSE["Reverse Peering: peering-hub-to-spoke-reverse<br/>import_custom_routes: true"]
        SPOKE_SUBNET["Analytics Subnet: 10.20.1.0/24<br/>Region: asia-south1"]
    end

    subgraph PARTNER["Partner / Vendor VPC (External)"]
        PARTNER_PEER["External Vendor Peering<br/>(Administered by Partner)"]
    end

    HUB_SUBNET <===>|High-Throughput Andromeda SDN| SPOKE_SUBNET
    PEER_FORWARD <===>|Automated Bi-Directional Handshake (ACTIVE)| PEER_REVERSE
    PEER_FORWARD -.->|Scenario 2: Uni-directional Peering| PARTNER_PEER
```

---

## Scenarios Illustrated

### Scenario 1: Bi-directional Peering (Internal Hub-and-Spoke)
- Connects `peering-demo-hub-vpc` to `peering-demo-spoke-vpc`.
- **`auto_create_reverse_peering: true`**: Automatically creates the reverse peering in the spoke VPC, immediately bringing the connection to `ACTIVE` state.
- **Route Exchange**: Hub VPC exports custom routes (`export_custom_routes = true`), and the module automatically sets `import_custom_routes = true` on the reverse peering.

### Scenario 2: Uni-directional Peering (External Partner / Vendor)
- Connects `peering-demo-hub-vpc` to an external partner VPC (`projects/vendor-corp-net/...`).
- **`auto_create_reverse_peering: false`**: The peering remains `INACTIVE` until the external vendor configures their matching return peering link.

---

## Files in this Directory

| File | Purpose |
|---|---|
| [`main.tf`](./main.tf) | Provisions the demo Hub and Spoke VPCs/subnets and calls the `network-peering` module. |
| [`peering.yaml`](./peering.yaml) | Declarative configuration defining peering relationships, route policies, and handshake settings. |
| [`provider.tf`](./provider.tf) | Configures the Google provider and Terraform version constraints. |
| [`outputs.tf`](./outputs.tf) | Exports VPC IDs, self-links, peering IDs, and operational states (`ACTIVE`/`INACTIVE`). |
| [`README.md`](./README.md) | Architectural documentation, walkthrough, and verification commands. |

---

## Declarative Peering Topology (`peering.yaml`)

```yaml
# ==============================================================================
# VPC NETWORK PEERINGS CONFIGURATION
# ==============================================================================
peerings:
  # Scenario 1: Bi-directional peering (Both sides created automatically)
  - name: "peering-hub-to-spoke"
    peer_network_self_link: "projects/yuvaraj-internal-project/global/networks/peering-demo-spoke-vpc"
    auto_create_reverse_peering: true
    export_custom_routes: true
    import_custom_routes: false
    export_subnet_routes_with_public_ip: false
    import_subnet_routes_with_public_ip: false

  # Scenario 2: Uni-directional peering (Remote side managed by partner or vendor)
  - name: "peering-hub-to-vendor"
    peer_network_self_link: "projects/vendor-corp-net/global/networks/vpc-vendor"
    auto_create_reverse_peering: false
    export_custom_routes: false
    import_custom_routes: true
    export_subnet_routes_with_public_ip: false
    import_subnet_routes_with_public_ip: false
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

## Verification Commands

After applying, verify that the VPC peering connections and dynamic routes are operational using `gcloud`:

### 1. Check Peering Status on the Hub VPC
```bash
gcloud compute networks peerings list --network=peering-demo-hub-vpc
```

Expected output:
```
NAME                    NETWORK               PEER_NETWORK            PEER_PROJECT             STATE   STATE_DETAILS
peering-hub-to-spoke    peering-demo-hub-vpc  peering-demo-spoke-vpc  yuvaraj-internal-project ACTIVE  [CONNECTED]
peering-hub-to-vendor   peering-demo-hub-vpc  vpc-vendor              vendor-corp-net          INACTIVE Waiting for peer
```

### 2. Check Peering Status on the Spoke VPC
```bash
gcloud compute networks peerings list --network=peering-demo-spoke-vpc
```

Expected output:
```
NAME                            NETWORK                 PEER_NETWORK          STATE   STATE_DETAILS
peering-hub-to-spoke-reverse    peering-demo-spoke-vpc  peering-demo-hub-vpc  ACTIVE  [CONNECTED]
```

### 3. Verify Route Exchange
```bash
gcloud compute routes list \
  --filter="network:peering-demo-hub-vpc AND description:peering-hub-to-spoke"
```

---

## Cleanup

To tear down all resources provisioned by this example:

```bash
terraform destroy
```
