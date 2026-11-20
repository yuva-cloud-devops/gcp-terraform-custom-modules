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

### 2. `audit-compliance-infra`
- **Purpose**: Declarative provisioning of Google Cloud Data Access Audit Logging (Project/Folder/Org scopes), centralized SIEM log routing (Storage, BigQuery, Pub/Sub), automated writer identity IAM delegation, and built-in CIS Google Cloud Platform Foundations Benchmark Section 2 log-based security metrics.
- **Documentation**: [`audit-compliance-infra/README.md`](./audit-compliance-infra/README.md)
- **Reference Example**: [`examples/secops/audit-compliance-setup/`](../examples/secops/audit-compliance-setup/)

### 3. `zero-trust-security-infra`
- **Purpose**: Declarative provisioning of Zero Trust Access and Passwordless/Keyless Authentication on Google Cloud via YAML. Eliminates public IP requirements and long-lived service account keys by deploying Cloud Identity-Aware Proxy (IAP) for TCP tunneling (SSH/RDP) and Web Applications, alongside Workload Identity Federation (WIF) for keyless CI/CD authentication (GitHub Actions, GitLab, AWS, Azure, OIDC/SAML providers).
- **Documentation**: [`zero-trust-security-infra/README.md`](./zero-trust-security-infra/README.md)
- **Reference Example**: [`examples/secops/zero-trust-setup/`](../examples/secops/zero-trust-setup/)

### 4. `edge-security-infra`
- **Purpose**: Declarative provisioning of Perimeter Security, Layer 7 WAF, Deep Packet Inspection (DPI), and Data Loss Prevention (DLP) boundaries via YAML. Deploys Cloud Armor security policies with OWASP Top 10 preconfigured rulesets, Layer 7 Adaptive Protection, rate limiting, and geo-fencing, alongside Cloud IDS intrusion detection endpoints and VPC Service Controls (VPC SC) perimeters with Access Context Manager.
- **Documentation**: [`edge-security-infra/README.md`](./edge-security-infra/README.md)
- **Reference Example**: [`examples/secops/edge-security-setup/`](../examples/secops/edge-security-setup/)

### 5. `threat-posture-infra`
- **Purpose**: Declarative provisioning of continuous vulnerability notification streaming, BigQuery security finding data lakes, and real-time configuration drift feeds via YAML. Integrates Security Command Center (SCC v2) for active threat and compliance finding notifications with Cloud Asset Inventory (CAI) real-time project feeds across Firewalls, IAM, KMS, and Cloud Storage.
- **Documentation**: [`threat-posture-infra/README.md`](./threat-posture-infra/README.md)
- **Reference Example**: [`examples/secops/threat-posture-setup/`](../examples/secops/threat-posture-setup/)

### 6. `pki-data-security-infra`
- **Purpose**: Declarative provisioning of Private PKI trust hierarchies, centralized TLS lifecycle routing, and automated sensitive data discovery via YAML. Deploys Google Cloud Certificate Authority Service (CAS) for `DEVOPS` and `ENTERPRISE` CA pools and Root/Subordinate CAs, Certificate Manager for DNS authorizations and HTTPS Load Balancer Certificate Maps, and Cloud Data Loss Prevention (Cloud DLP / Sensitive Data Protection) for inspection templates, character masking de-identification, and scheduled storage/BigQuery scan triggers.
- **Documentation**: [`pki-data-security-infra/README.md`](./pki-data-security-infra/README.md)
- **Reference Example**: [`examples/secops/pki-data-security-setup/`](../examples/secops/pki-data-security-setup/)

### 7. `container-security-infra`
- **Purpose**: Declarative provisioning of Software Supply Chain Security, Container Integrity, and Deploy-Time Admission Controls via YAML. Deploys Container Analysis (Grafeas) metadata notes for vulnerability scan and security approvals, Binary Authorization attestors with cryptographic verification authorities, builder and verifier IAM bindings, and deploy-time admission policies supporting global system allowlists and cluster-specific dry-run or enforced blocking.
- **Documentation**: [`container-security-infra/README.md`](./container-security-infra/README.md)
- **Reference Example**: [`examples/secops/container-security-setup/`](../examples/secops/container-security-setup/)





