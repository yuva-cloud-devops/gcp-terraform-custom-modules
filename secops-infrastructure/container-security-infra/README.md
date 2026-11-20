# Container Security Infrastructure Module (`container-security-infra`)

Production-grade, dynamic, YAML-driven Terraform module for Google Cloud Platform **Container Security and Software Supply Chain Integrity**, covering **Container Analysis (Grafeas)** and **Binary Authorization**.

---

## Architecture Overview

```
       [CI/CD Build & Scan Pipeline]
                     │
         (Vulnerability Scan Passed)
                     ▼
       ┌───────────────────────────┐
       │ Cloud KMS Asymmetric Key  │ ── Sign Image Digest
       └─────────────┬─────────────┘
                     │ (Create Attestation Occurrence)
                     ▼
       ┌───────────────────────────┐
       │  Container Analysis Note  │ ── (Metadata Store / Grafeas API)
       └─────────────┬─────────────┘
                     │ (Anchor)
                     ▼
       ┌───────────────────────────┐
       │ Binary Authorization      │
       │ Attestor                  │ ── Public Key / KMS Verifier
       └─────────────┬─────────────┘
                     │ (Enforce)
                     ▼
       ┌───────────────────────────┐
       │ Binary Authorization      │
       │ Admission Policy          │ ── Evaluates at Deploy Time:
       └─────────────┬─────────────┘    • Allowlist: Google system images
                     │                  • Default Rule: Require Attestation
                     │                  • Mode: Dry-Run vs Enforced Block
                     ▼
            [ GKE K8s Cluster ]
       (Permits or Rejects Pod Deployments)
```

---

## Features

- **Container Analysis (Grafeas) Notes**: Establishes metadata verification anchors for vulnerability scans, security approvals, and software supply chain attestations.
- **Granular IAM Control**: Configures note attacher roles (`roles/containeranalysis.notes.attacher`) for CI/CD builders.
- **Binary Authorization Attestors**: Defines cryptographic verification authorities with support for PKIX/ECDSA/RSA public keys or ASCII-armored PGP keys.
- **Deploy-time Admission Policy**: Project-wide and per-cluster admission enforcement rules with audit-only dry-run capability (`DRYRUN_AUDIT_LOG_ONLY`) and production blocking (`ENFORCED_BLOCK_AND_AUDIT_LOG`).
- **Dynamic Resource References**: Automatically resolves note references and attestor paths from simple keys without manual URL string construction.

---

## YAML Configuration Specification

```yaml
container_security:
  project_id: "my-gcp-project-id"

  # ---------------------------------------------------------------------------
  # 1. Container Analysis Notes
  # ---------------------------------------------------------------------------
  container_analysis_notes:
    secops-security-attestation-note:
      short_description: "SecOps Security Scan Attestation Authority"
      long_description: "Attestation note verifying that container image passed vulnerability scanning."
      iam_members:
        - role: "roles/containeranalysis.notes.attacher"
          member: "serviceAccount:builder-sa@my-gcp-project-id.iam.gserviceaccount.com"

  # ---------------------------------------------------------------------------
  # 2. Binary Authorization Attestors
  # ---------------------------------------------------------------------------
  attestors:
    secops-security-attestor:
      description: "Attestor verifying CI/CD security scanning"
      note_ref: "secops-security-attestation-note"
      public_keys:
        - id: "secops-pkix-key"
          comment: "Production ECDSA P256 verification key"
          pkix_public_key:
            public_key_pem: |
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----
            signature_algorithm: "ECDSA_P256_SHA256"
      iam_members:
        - role: "roles/binaryauthorization.attestorsVerifier"
          member: "serviceAccount:service-PROJECT_NUMBER@container-engine-robot.iam.gserviceaccount.com"

  # ---------------------------------------------------------------------------
  # 3. Binary Authorization Deploy-time Policy
  # ---------------------------------------------------------------------------
  policy:
    description: "Enterprise Zero-Trust Container Admission Policy"
    global_policy_evaluation_mode: "ENABLE"
    admission_whitelist_patterns:
      - "gcr.io/google_containers/*"
      - "k8s.gcr.io/*"
      - "gke.gcr.io/*"
      - "gcr.io/stackdriver-agents/*"
    default_admission_rule:
      evaluation_mode: "REQUIRE_ATTESTATION"
      enforcement_mode: "DRYRUN_AUDIT_LOG_ONLY"
      require_attestations_by:
        - "secops-security-attestor"
    cluster_admission_rules:
      "asia-south1.secops-prod-gke-cluster":
        evaluation_mode: "REQUIRE_ATTESTATION"
        enforcement_mode: "ENFORCED_BLOCK_AND_AUDIT_LOG"
        require_attestations_by:
          - "secops-security-attestor"
```

---

## Terraform Usage

```hcl
module "container_security" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//secops-infrastructure/container-security-infra?ref=main"
  config_file_path = "./container-security.yaml"
}

output "container_notes" {
  value = module.container_security.container_analysis_notes
}

output "attestors" {
  value = module.container_security.attestors
}

output "policy" {
  value = module.container_security.policy
}
```
