# PKI & Data Security Infrastructure Module (`pki-data-security-infra`)

This production-grade, YAML-driven Terraform module orchestrates **Google Cloud Certificate Authority Service (CAS)**, **Certificate Manager**, and **Cloud Data Loss Prevention (Cloud DLP / Sensitive Data Protection)**.

---

## 🏗️ Architecture Overview

```
                                  +---------------------------------------------+
                                  |         pki-data-security.yaml              |
                                  +---------------------------------------------+
                                         |                   |               |
                                         v                   v               v
               +----------------------------------+          |  +-----------------------------+
               |  Certificate Authority Service   |          |  |          Cloud DLP          |
               |             (CAS)                |          |  |  (Sensitive Data Discovery) |
               +----------------------------------+          |  +-----------------------------+
               | * CA Pools (DevOps / Enterprise) |          |  | * Inspection Templates      |
               | * Root & Subordinate CAs         |          |  |   (PII, Credentials, Cards) |
               | * Issuance & Lifetime Policies   |          |  | * De-identification Configs|
               +----------------------------------+          |  | * Storage / BQ Scan Triggers|
                                 |                           |  +-----------------------------+
                                 v                           v
               +--------------------------------------------------------------+
               |                    Certificate Manager                       |
               +--------------------------------------------------------------+
               | * Private & Google-Managed Public SSL/TLS Certificates       |
               | * DNS Authorizations for Auto-Renewing Wildcard Certs        |
               | * Certificate Maps & Map Entries (Direct to HTTPS LBs)       |
               +--------------------------------------------------------------+
```

---

## 🔒 Security Features

1. **Certificate Authority Service (CAS / Private CA):**
   * **CA Pools:** Supports `DEVOPS` (cost-effective, high-throughput microservice certs) and `ENTERPRISE` (high-assurance, FIPS 140-2 Level 3 HSM keys).
   * **Root & Subordinate CAs:** Configurable key algorithms (`RSA_PKCS1_4096_SHA256`, `ECDSA_P256_SHA256`), x509 subject attributes, and CRL/AIA publishing.
   * **Issuance Policies:** Enforces maximum certificate lifetime (e.g. 30 days) and allowed cryptographic algorithms.

2. **Certificate Manager:**
   * **Decoupled TLS Routing:** Connects dynamic certificates to Google Cloud HTTPS Load Balancers via Certificate Maps and SNI Hostname matchers without downtime.
   * **Automated DNS Authorization:** Provisions DNS CNAME challenge records for Google-managed public wildcard certificates.
   * **CAS Integration:** Certificate Issuance Configs allow Certificate Manager to automatically issue and renew private internal certificates from your CAS pool.

3. **Cloud Data Loss Prevention (Cloud DLP):**
   * **Inspection Templates:** Standardizes discovery of sensitive info types (`EMAIL_ADDRESS`, `CREDIT_CARD_NUMBER`, `AUTH_TOKEN`, `GCP_API_KEY`, etc.).
   * **De-identification Templates:** Masks sensitive data using customizable character masking (`***-**-1234`) or string replacement (`[REDACTED]`).
   * **Periodic Job Triggers:** Automates scheduled discovery scans over Cloud Storage buckets and BigQuery datasets.

---

## 📋 YAML Configuration Specification

```yaml
pki_data_security:
  project_id: "my-security-project"
  location: "asia-south1"

  # ---------------------------------------------------------------------------
  # 1. Private CA Service Pools
  # ---------------------------------------------------------------------------
  ca_pools:
    internal-workload-pool:
      tier: "DEVOPS" # DEVOPS or ENTERPRISE
      description: "Private CA pool for internal microservices and mTLS"
      publishing_options:
        publish_ca_cert: true
        publish_crl: true

  # ---------------------------------------------------------------------------
  # 2. Certificate Authorities (Root or Intermediate)
  # ---------------------------------------------------------------------------
  certificate_authorities:
    internal-root-ca:
      ca_pool: "internal-workload-pool"
      type: "SELF_SIGNED"
      lifetime: "315360000s" # 10 years
      key_spec:
        algorithm: "RSA_PKCS1_4096_SHA256"
      subject:
        common_name: "Internal Root CA"
        organization: "SecOps Enterprise Trust"
        country_code: "IN"

  # ---------------------------------------------------------------------------
  # 3. Certificate Manager
  # ---------------------------------------------------------------------------
  certificate_manager:
    dns_authorizations:
      secops-dns-auth:
        domain: "secops.internal.example.com"
        description: "DNS authorization for internal domain verification"

    certificate_maps:
      secops-lb-cert-map:
        description: "Certificate Map attached to HTTPS Load Balancer Target Proxy"
        entries:
          api-entry:
            hostname: "secops.internal.example.com"
            matcher: "PRIMARY"

  # ---------------------------------------------------------------------------
  # 4. Cloud DLP (Sensitive Data Protection)
  # ---------------------------------------------------------------------------
  dlp:
    inspect_templates:
      secops-pii-inspection:
        display_name: "SecOps Standard PII & Secret Scanner"
        description: "Scans for emails, credit cards, auth tokens, and GCP API keys"
        info_types:
          - "EMAIL_ADDRESS"
          - "CREDIT_CARD_NUMBER"
          - "AUTH_TOKEN"
          - "GCP_API_KEY"
        min_likelihood: "LIKELY"

    deidentify_templates:
      secops-masking:
        display_name: "SecOps PII Character Masking"
        description: "Masks last characters with asterisks"
        transformation_type: "mask"
        mask_character: "*"
        number_to_mask: 4
        reverse_order: true
```

---

## 🚀 Module Usage

```hcl
module "pki_data_security" {
  source           = "git::https://github.com/your-org/gcp-terraform-custom-modules.git//secops-infrastructure/pki-data-security-infra?ref=main"
  config_file_path = "./pki-data-security.yaml"
}
```

---

## 🔍 Verification Commands

```powershell
# 1. Verify CA Pools
gcloud privateca pools list --location=asia-south1 --project=YOUR_PROJECT_ID

# 2. Verify Certificate Authorities
gcloud privateca roots list --pool=internal-workload-pool --location=asia-south1 --project=YOUR_PROJECT_ID

# 3. Verify Certificate Manager Maps
gcloud certificate-manager maps list --project=YOUR_PROJECT_ID

# 4. Verify DLP Inspection Templates
gcloud dlp inspect-templates list --project=YOUR_PROJECT_ID
```
