# Google Cloud Security Operations (SecOps) Infrastructure Domain

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%3E%3D5.0-4285F4.svg?logo=google-cloud)](https://cloud.google.com/)
[![Security Hardened](https://img.shields.io/badge/SecOps-Zero%20Trust%20%7C%20CMEK%20%7C%20Compliance-success.svg)](#implementation-sequence)

The **SecOps Infrastructure** domain provides a cohesive suite of enterprise-grade, YAML-driven Terraform custom modules to enforce cryptographic security, continuous auditing, perimeter protection, identity federation, zero-trust access, and software supply chain integrity across Google Cloud Platform landing zones.

---

## Domain Architecture & Module Catalog

```
secops-infrastructure/
├── 1. crypto-secrets-infra/          # Cloud KMS (CMEK, HSM), Secret Manager (Replication, IAM)
├── 2. audit-compliance-infra/        # Data Access Audit Logs, Centralized SIEM Log Sinks
├── 3. zero-trust-security-infra/     # Identity-Aware Proxy (IAP), Workload Identity Federation (WIF)
├── 4. edge-security-infra/           # Cloud Armor, Cloud IDS, VPC Service Controls (VPC SC)
├── 5. threat-posture-infra/          # Security Command Center (SCC), Cloud Asset Inventory
├── 6. pki-data-security-infra/       # CAS (Private CA), Certificate Manager, Cloud DLP
└── 7. container-security-infra/      # Binary Authorization, Artifact/Container Analysis
```

---

## Implementation Sequence

When provisioning SecOps infrastructure, execute modules in this dependency order:

1. **`crypto-secrets-infra` & `audit-compliance-infra` (Start First)**
   - Every downstream workload (Cloud Storage, databases, Compute Engine, GKE) requires Customer-Managed Encryption Keys (CMEK), secure secret storage, and centralized audit logging sinks before workload provisioning begins.
2. **`zero-trust-security-infra` & `edge-security-infra` (Next)**
   - Integrates directly into your **Networking Infrastructure** (Shared VPC, Load Balancers, and private VM bastion access).
3. **`threat-posture-infra` & `pki-data-security-infra`**
   - Configures organization-wide posture guardrails, compliance scans, and internal SSL/TLS Private CA infrastructure.
4. **`container-security-infra` (Before GKE)**
   - Deploys Binary Authorization policies and Artifact Analysis attestations before starting GKE and containerized application deployments.

---

## Active Modules

### 1. `crypto-secrets-infra`
- **Purpose**: Declarative provisioning of Cloud KMS Keyrings (regional, multi-regional, global), CryptoKeys (Software & FIPS 140-2 Level 3 HSM), automated rotation schedules, CMEK service agent delegations, and Secret Manager secrets with automatic or multi-region user-managed replication and CEL-based IAM policies.
- **Documentation**: [`crypto-secrets-infra/README.md`](./crypto-secrets-infra/README.md)
- **Reference Example**: [`examples/secops/crypto-secrets-setup/`](../examples/secops/crypto-secrets-setup/)
