# GCP Foundation Infrastructure & Project Factory Module

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Google Provider](https://img.shields.io/badge/Provider-Google%20%3E%3D5.0.0-4285F4?logo=google-cloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![Random Provider](https://img.shields.io/badge/Provider-Random%20%3E%3D3.5.0-844FBA?logo=terraform&logoColor=white)](https://registry.terraform.io/providers/hashicorp/random/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An enterprise-grade, YAML-driven Terraform foundation module for Google Cloud Platform (GCP). This module automates the provisioning of your end-to-end cloud resource hierarchy, implementing the **Project Factory** pattern, multi-tier folder structures, dynamic API activation, granular IAM governance with CEL conditions, custom workload service accounts, and enterprise security guardrails.

---

## Architecture Overview

```mermaid
flowchart TD
    YAML["hierarchy.yaml<br/>(Declarative Hierarchy Specification)"] --> Locals["0-locals.tf<br/>(Parser & Flattening Pipeline)"]

    Locals --> OrgIAM["1-org-iam.tf<br/>google_organization_iam_member"]
    Locals --> TopFolders["2-folders.tf<br/>google_folder (Top-Level)"]
    TopFolders --> SubFolders["2-folders.tf<br/>google_folder (Sub-Folders)"]

    TopFolders --> FolderIAM["4-iam.tf<br/>google_folder_iam_member<br/>(CEL Conditions Supported)"]
    SubFolders --> FolderIAM

    SubFolders --> Projects["3-projects.tf<br/>google_project (Project Factory)<br/>Prefixes + Random Suffix + Billing + Deletion Protection"]
    TopFolders --> Projects

    Projects --> Security["4-iam.tf<br/>google_project_default_service_accounts<br/>(Deprivilege Default Compute SA)"]
    Projects --> APIs["5-apis.tf<br/>google_project_service<br/>(Dynamic API Enablement)"]
    Projects --> ProjectIAM["6-users-groups.tf<br/>google_project_iam_member<br/>(User / Group IAM with Conditions)"]
    Projects --> WorkloadSA["7-custom-service-accounts.tf<br/>google_service_account &<br/>google_project_iam_member (SA Roles)"]
```

### Resource Hierarchy Model

```mermaid
flowchart TD
    Org["GCP Organization<br/>(organizations/123456789012)"]
    Org --> OrgBindings["Org IAM Bindings<br/>(e.g., Organization Admin, Billing Admin)"]
    Org --> TopFolder1["Top-Level Folder: core"]
    Org --> TopFolder2["Top-Level Folder: workloads"]

    TopFolder1 --> ProjectCore["Project: acme-core-security-audit"]
    TopFolder2 --> SubFolderDev["Sub-Folder: development"]
    TopFolder2 --> SubFolderProd["Sub-Folder: production"]

    SubFolderDev --> ProjectDev["Project: acme-dev-ecommerce-api-xxxx"]
    ProjectDev --> APIsDev["Enabled APIs<br/>(compute, container, storage, build)"]
    ProjectDev --> IAMDev["Project IAM<br/>(Roles with CEL Conditions)"]
    ProjectDev --> SADev["Custom Workload Service Accounts<br/>(ecommerce-backend-sa, cicd-deployer-sa)"]
    ProjectDev --> SecDev["Hardening<br/>(Deprivilege Default Compute SA)"]
```

---

## Key Features

1. **Declarative Hierarchy (`hierarchy.yaml`)**:
   - Manage your entire cloud foundation—from organization IAM down to individual project service account roles—in a clean, version-controlled YAML specification.
2. **Multi-Tier Folder Architecture (`2-folders.tf`)**:
   - Automated creation of top-level folders parented by the GCP Organization and nested sub-folders parented by top-level folders.
3. **Enterprise Project Factory (`3-projects.tf` & `0-locals.tf`)**:
   - Automated project provisioning placed under designated target folders.
   - Built-in naming conventions: configurable prefix, base name, and optional randomized 4-character suffix (`random_string.project_suffix`) to ensure global project ID uniqueness.
   - Automatic billing account association.
   - Metadata labels for FinOps and organizational cost center attribution.
   - Default project deletion protection (`deletion_policy = "PREVENT"`) to avoid accidental catastrophic data loss.
4. **Security Hardening by Default (`4-iam.tf`)**:
   - **Deprivilege Default Service Accounts**: Automatically removes the default over-privileged `roles/editor` binding from the default Compute Engine service account (`{project_number}-compute@developer.gserviceaccount.com`), enforcing least privilege baseline.
5. **Granular IAM with CEL Conditions (`1-org-iam.tf`, `4-iam.tf`, `6-users-groups.tf`)**:
   - Non-authoritative IAM member bindings across Organization, Folders, and Projects.
   - Full support for Common Expression Language (CEL) IAM conditions (e.g., time-bound temporary access, IP constraints, resource tags).
6. **Dynamic API & Service Enablement (`5-apis.tf`)**:
   - Project-by-project API activation.
   - Safe destroy protection: sets `disable_on_destroy = false` and `disable_dependent_services = false` to prevent unexpected service disruption during configuration changes.
7. **Custom Workload Service Accounts (`7-custom-service-accounts.tf`)**:
   - Provisions dedicated service accounts per project for application workloads, Google Kubernetes Engine (GKE) Workload Identity, or CI/CD pipelines.
   - Automatically binds specified IAM roles to custom service accounts within their target project.

---

## File Structure & Module Breakdown

| File | Purpose | Managed Resources |
|---|---|---|
| [`0-locals.tf`](./0-locals.tf) | YAML configuration parsing, schema flattening, and project random suffix generation | `random_string.project_suffix` |
| [`1-org-iam.tf`](./1-org-iam.tf) | Organization-level IAM member bindings | `google_organization_iam_member.org` |
| [`2-folders.tf`](./2-folders.tf) | Top-level folders and nested sub-folder hierarchy | `google_folder.top`, `google_folder.sub` |
| [`3-projects.tf`](./3-projects.tf) | Project Factory creating projects with billing and deletion protection | `google_project.projects` |
| [`4-iam.tf`](./4-iam.tf) | Folder IAM bindings with CEL conditions & default SA deprivileging | `google_folder_iam_member.folders`, `google_project_default_service_accounts.deprivilege` |
| [`5-apis.tf`](./5-apis.tf) | Dynamic GCP service and API enablement per project | `google_project_service.apis` |
| [`6-users-groups.tf`](./6-users-groups.tf) | Project-level IAM bindings for users, groups, and service accounts | `google_project_iam_member.users` |
| [`7-custom-service-accounts.tf`](./7-custom-service-accounts.tf) | Workload service account creation and project IAM role assignments | `google_service_account.sa`, `google_project_iam_member.sa_roles` |
| [`variables.tf`](./variables.tf) | Input variables for configuration path | Variable `yaml_config_path` |
| [`outputs.tf`](./outputs.tf) | Exported outputs for folder IDs, project IDs, and service accounts | Outputs `organization_id`, `folders`, `projects`, etc. |
| [`versions.tf`](./versions.tf) | Terraform version and provider constraints | Providers `hashicorp/google`, `hashicorp/random` |

---

## Requirements

| Name | Version |
|---|---|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | `>= 1.5.0` |
| <a name="requirement_google"></a> [google](#requirement\_google) | `>= 5.0.0, < 7.0.0` |
| <a name="requirement_random"></a> [random](#requirement\_random) | `>= 3.5.0` |

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `yaml_config_path` | Path to the hierarchy YAML configuration file defining org IAM, folder hierarchy, projects, APIs, and service accounts. | `string` | `"./hierarchy.yaml"` | no |

---

## Outputs

| Name | Description | Type |
|---|---|---|
| `organization_id` | The target GCP Organization ID specified in the configuration. | `string` |
| `folders` | Map of all created top-level and sub-folders mapped to their GCP resource names (e.g., `'workloads' => 'folders/123456789012'`). | `map(string)` |
| `projects` | Detailed map of created projects including `project_id`, `project_number`, and `folder_id`. | `map(object)` |
| `project_ids` | Lookup map of project name to created GCP project ID. | `map(string)` |
| `project_numbers` | Lookup map of project name to GCP project number. | `map(string)` |
| `service_accounts` | Map of created custom service accounts (keyed as `'<project_name>-<account_id>'`) to their generated email addresses. | `map(string)` |

---

## YAML Configuration Reference (`hierarchy.yaml`)

The module is driven entirely by a YAML configuration file. Below is the full schema specification:

```yaml
# Target GCP Organization & Billing Account
organization_id: "123456789012"
billing_account_id: "012345-56789A-BCDEF0"

# 1. Organization IAM Bindings (Optional)
organization_iam:
  - role: "roles/resourcemanager.organizationAdmin"
    members:
      - "group:gcp-org-admins@mycompany.com"
  - role: "roles/billing.admin"
    members:
      - "group:finops-leads@mycompany.com"

# 2. Top-Level Folders (Parent = Organization Root)
top_level_folders:
  - name: "core"
    iam:
      - role: "roles/resourcemanager.folderViewer"
        members: ["group:secops-auditors@mycompany.com"]
  - name: "workloads"
    iam:
      - role: "roles/resourcemanager.folderViewer"
        members: ["group:cloud-leads@mycompany.com"]

# 3. Sub-Folders (Parent = Specified Top-Level Folder)
sub_folders:
  - name: "development"
    parent: "workloads"
    iam:
      - role: "roles/viewer"
        members: ["group:developers@mycompany.com"]
      # Optional IAM Condition (CEL Expression)
      - role: "roles/resourcemanager.folderAdmin"
        members: ["user:lead-dev@mycompany.com"]
        condition:
          title: "temporary_lead_access"
          description: "Expires end of year"
          expression: 'request.time < timestamp("2026-12-31T23:59:59Z")'
  - name: "production"
    parent: "workloads"
    iam:
      - role: "roles/viewer"
        members: ["group:sre-team@mycompany.com"]

# 4. Projects (Project Factory)
projects:
  - name: "ecommerce-api"
    prefix: "acme-dev"               # Optional prefix for project ID (e.g. acme-dev-ecommerce-api-xxxx)
    target_folder: "development"      # Name of folder (top-level or sub-folder) to house the project
    random_id: true                  # Append a 4-char random string to guarantee uniqueness (default: true)
    deprivilege_default_sa: true     # Strip broad Editor role from default Compute Engine SA (default: true)
    apis:                            # GCP APIs to activate
      - "compute.googleapis.com"
      - "container.googleapis.com"
      - "storage.googleapis.com"
      - "cloudbuild.googleapis.com"
    labels:                          # GCP labels for cost attribution and governance
      environment: "dev"
      cost_center: "engineering"
    iam:                             # Project-level IAM bindings
      - role: "roles/viewer"
        members: ["group:developers@mycompany.com"]
      - role: "roles/storage.objectAdmin"
        members: ["group:developers@mycompany.com"]
    custom_service_accounts:         # Dedicated workload service accounts
      - account_id: "ecommerce-backend-sa"
        display_name: "Ecommerce Backend Workload Identity"
        roles:
          - "roles/storage.objectUser"
          - "roles/logging.logWriter"
      - account_id: "cicd-deployer-sa"
        display_name: "CI/CD Pipeline SA"
        roles:
          - "roles/container.developer"
          - "roles/storage.admin"

  - name: "security-audit"
    prefix: "acme-core"
    target_folder: "core"
    random_id: false                 # Fixed project ID: "acme-core-security-audit"
    deprivilege_default_sa: true
    apis:
      - "logging.googleapis.com"
      - "monitoring.googleapis.com"
    labels:
      environment: "prod"
      cost_center: "security"
    iam:
      - role: "roles/logging.admin"
        members: ["group:secops-auditors@mycompany.com"]
    custom_service_accounts: []
```

---

## Usage Example

### 1. Module Invocation (`main.tf`)

```hcl
module "foundation_infrastructure" {
  source           = "git::https://github.com/yuva-cloud-devops/gcp-terraform-custom-modules.git//foundation-infrastructure?ref=main"
  yaml_config_path = "${path.module}/hierarchy.yaml"
}
```

### 2. Output References (`outputs.tf`)

```hcl
output "created_folders" {
  description = "All folders mapped to GCP resource IDs"
  value       = module.foundation_infrastructure.folders
}

output "created_projects" {
  description = "Summary of provisioned GCP projects"
  value       = module.foundation_infrastructure.projects
}

output "workload_service_accounts" {
  description = "All created workload service accounts"
  value       = module.foundation_infrastructure.service_accounts
}
```

---

## Security & FinOps Best Practices

- **Least Privilege Access**: The module utilizes `google_*_iam_member` non-authoritative bindings, avoiding accidental purging of existing GCP role grants while explicitly provisioning required permissions.
- **Compute Engine SA Hardening**: Broad `roles/editor` access is automatically stripped via `google_project_default_service_accounts.deprivilege`, preventing VMs from inheriting unrestricted project privileges.
- **CEL IAM Conditions**: Grants can be constrained by time, dates, or resource tags using Common Expression Language (CEL), fulfilling compliance requirements for temporary or on-call privilege escalation.
- **FinOps Attribution**: Project labels (`environment`, `cost_center`, `team`) flow directly into GCP Cloud Billing export tables for chargeback and budget tracking.
- **Deletion Protection**: Every project is created with `deletion_policy = "PREVENT"` to safeguard critical foundation infrastructure against accidental `terraform destroy` commands.

---

## License

This module is released under the [MIT License](LICENSE).

