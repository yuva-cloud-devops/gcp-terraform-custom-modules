# Container Infrastructure Custom Terraform Module

A production-grade, 100% YAML-declarative Terraform module for enterprise Google Cloud Container Infrastructure, featuring:
- **Google Kubernetes Engine (GKE)**: Standard & Autopilot clusters, private cluster hardening, Workload Identity, and autoscaling node pools.
- **GKE Ingress, Gateway API & NEGs**: Gateway API controller, static IP reservations, standalone NEGs, and Google-managed SSL certificates.
- **Cloud KMS & Secret Manager Integration (Consuming External Security Resources)**:
  - **KMS Application-Layer Encryption**: If an external KMS key is specified in YAML, enables GKE database encryption (`etcd` envelope encryption) and binds the GKE robot service agent. If not specified, KMS encryption is not enabled.
  - **Secret Manager Add-on**: Enabled only when `addons.secret_manager: true` is configured in YAML. If omitted or false, the add-on is not installed.
  - **Workload Identity Secret Access**: Grants Kubernetes Pods (KSA) direct `roles/secretmanager.secretAccessor` permissions on existing Secret Manager secrets.
  - **Dedicated Workload Service Accounts**: Manages GSA-to-KSA trust mappings (`roles/iam.workloadIdentityUser`).
- **Google Artifact Registry (GAR)**: Docker repositories with tag immutability and cleanup policies.

---

## Directory Structure

```text
container-infrastructure/
├── 0-locals.tf                # Ingestion, normalization, GKE mode, Gateway & Secrets parsing
├── 1-artifact-registry.tf     # Artifact Registry repositories & policies
├── 2-gke-cluster.tf           # Node SA, IAM roles, Control Plane, Addons & KMS integration
├── 3-gke-node-pools.tf        # Standard GKE Node Pools & autoscaling
├── 4-gke-ingress-gateway.tf   # Gateway static IPs, Standalone NEGs & Managed SSL certificates
├── 5-gke-secrets-kms.tf       # External KMS IAM attachment & Secret Manager KSA permissions
├── variables.tf               # Input variables (yaml_content / config_file_path)
├── outputs.tf                 # Structured cluster endpoints, credentials, NEGs & summary
├── versions.tf                # Terraform & Google provider constraints
└── README.md                  # Documentation & YAML schemas
```

---

## YAML Configuration Specification

### Example: Standard Cluster with External KMS & Secret Manager Integration

```yaml
container_infrastructure:
  project_id: "yuvaraj-internal-project"
  region: "asia-south1"
  network: "projects/yuvaraj-internal-project/global/networks/testing-environment-vpc"
  subnetwork: "projects/yuvaraj-internal-project/regions/asia-south1/subnetworks/testing-environment-private-subnet-mumbai"
  tags:
    environment: "dev"
    managed-by: "terraform"

  # ==========================================================================
  # 1. Artifact Registry
  # ==========================================================================
  artifact_registries:
    app-docker-repo:
      description: "Docker repository for web application containers"
      format: "DOCKER"
      immutable_tags: false
      vulnerability_scanning: false
      cleanup_policies:
        keep_recent_versions:
          action: "KEEP"
          condition:
            tag_state: "ANY"
          most_recent_versions:
            keep_count: 5

  # ==========================================================================
  # 2. GKE Clusters (Standard or Autopilot)
  # ==========================================================================
  clusters:
    gke-standard-cluster:
      mode: "STANDARD"
      location: "asia-south1"
      pods_secondary_range_name: "gke-pods-mumbai"
      services_secondary_range_name: "gke-services-mumbai"
      master_ipv4_cidr_block: "172.16.0.0/28"
      enable_private_nodes: true
      enable_private_endpoint: false
      release_channel: "REGULAR"
      datapath_provider: "ADVANCED_DATAPATH"
      workload_identity: true
      deletion_protection: false

      # (Optional) Cloud KMS Application-Layer Encryption
      # If key_name is provided, database encryption is enabled and GKE robot SA is granted access.
      # If omitted or enabled: false, KMS encryption is not added.
      database_encryption:
        enabled: true
        key_name: "projects/yuvaraj-internal-project/locations/asia-south1/keyRings/my-existing-keyring/cryptoKeys/gke-secrets-key"

      # Addons & Gateway API
      addons:
        http_load_balancing: true
        gateway_api_channel: "CHANNEL_STANDARD" # Enables Gateway API Controller
        secret_manager: true                    # Set true to enable Secret Manager CSI Driver, or omit/false to skip
        gcs_fuse_csi_driver: false
        dns_cache: true

      master_authorized_networks:
        - cidr_block: "0.0.0.0/0"
          display_name: "public-admin-access"

      # Dedicated Node Pools
      node_pools:
        system-pool:
          machine_type: "e2-medium"
          disk_size_gb: 30
          disk_type: "pd-balanced"
          spot: false
          initial_node_count: 1
          autoscaling:
            min_node_count: 1
            max_node_count: 3
          management:
            auto_repair: true
            auto_upgrade: true
          shielded_instance_config:
            enable_secure_boot: true
            enable_integrity_monitoring: true
          labels:
            tier: "system"
          tags:
            - "gke-node"

  # ==========================================================================
  # 3. GKE Ingress, Gateway API & Network Endpoint Groups (NEGs)
  # ==========================================================================
  ingress_gateways:
    ip_reservations:
      gke-public-gateway-ip:
        type: "GLOBAL_EXTERNAL" # For kind: Gateway (gke-l7-global-external-managed)
        description: "Static Anycast IP for Public Gateway API"

      gke-internal-gateway-ip:
        type: "REGIONAL_INTERNAL" # For kind: Gateway (gke-l7-rilb)
        region: "asia-south1"
        subnetwork: "projects/yuvaraj-internal-project/regions/asia-south1/subnetworks/testing-environment-private-subnet-mumbai"
        description: "Static Internal IP for Internal Microservices Gateway"

    standalone_negs:
      gke-web-app-neg:
        zone: "asia-south1-a"
        network_endpoint_type: "GCE_VM_IP_PORT"
        default_port: 80
        description: "Standalone NEG for external Cloud Load Balancer integration"

  # ==========================================================================
  # 4. Access to Existing Secret Manager Secrets & Workload Identity
  # ==========================================================================
  secrets_and_config:
    # Grant KSA direct read access to existing Secret Manager secrets
    secret_manager_access:
      - secret_id: "app-database-credentials" # Created elsewhere
        namespace: "default"
        service_account: "app-workload-sa"

      - secret_id: "app-runtime-env"          # Created elsewhere
        namespace: "default"
        service_account: "app-workload-sa"

    # (Optional) Dedicated Workload Identity Service Accounts (GSA <-> KSA mapping)
    workload_service_accounts:
      app-workload-gsa:
        description: "Dedicated Google Service Account for web application Pods"
        roles:
          - "roles/secretmanager.secretAccessor"
        k8s_bindings:
          - namespace: "default"
            service_account: "app-workload-sa"
```

---

## How Pods Consume Existing Secret Manager Secrets

When `addons.secret_manager: true` is enabled, the Google Cloud Secret Manager add-on installs the Secrets Store CSI Driver into the cluster.

### 1. SecretProviderClass Manifest
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets-provider
  namespace: default
spec:
  provider: gcp
  parameters:
    secrets: |
      - resourceName: "projects/yuvaraj-internal-project/secrets/app-database-credentials/versions/latest"
        path: "database-url.txt"
      - resourceName: "projects/yuvaraj-internal-project/secrets/app-runtime-env/versions/latest"
        path: "runtime.env"
```

### 2. Pod Deployment Mounting Secrets as Files
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 2
  template:
    spec:
      serviceAccountName: app-workload-sa
      containers:
      - name: web-app
        image: asia-south1-docker.pkg.dev/yuvaraj-internal-project/app-docker-repo/web-app:v1
        volumeMounts:
        - name: secrets-store-inline
          mountPath: "/var/secrets"
          readOnly: true
      volumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "app-secrets-provider"
```
