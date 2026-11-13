# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the input YAML configuration file and flattens nested data structures
# (Organization IAM, folder hierarchy, projects, APIs, IAM bindings, and custom
# service accounts) into map/list collections suitable for Terraform 'for_each'.
# ==============================================================================

locals {
  # Parse and decode the YAML configuration file
  config = yamldecode(file(var.yaml_config_path))

  # ----------------------------------------------------------------------------
  # Organization-Level IAM
  # ----------------------------------------------------------------------------
  # Flattens organization IAM role-to-members mappings into individual bindings
  org_iam_flat = flatten([
    for binding in lookup(local.config, "organization_iam", []) : [
      for member in binding.members : {
        role   = binding.role
        member = member
        key    = "${binding.role}-${member}"
      }
    ]
  ])

  # ----------------------------------------------------------------------------
  # Folder ID Lookup Map
  # ----------------------------------------------------------------------------
  # Merges top-level and sub-folder resource references into a unified lookup map
  # (Folder Display Name => GCP Resource Name 'folders/{folder_id}')
  all_folders = merge(
    { for k, v in google_folder.top : k => v.name },
    { for k, v in google_folder.sub : k => v.name }
  )

  # ----------------------------------------------------------------------------
  # Folder-Level IAM
  # ----------------------------------------------------------------------------
  # Flattens folder-level IAM role bindings across top-level and sub-folders,
  # including optional CEL IAM conditions
  folder_iam_flat = flatten([
    for f in concat(
      lookup(local.config, "top_level_folders", []),
      lookup(local.config, "sub_folders", [])
      ) : [
      for binding in lookup(f, "iam", []) : [
        for member in binding.members : {
          folder_name = f.name
          role        = binding.role
          member      = member
          condition   = lookup(binding, "condition", null)
          key         = "${f.name}-${binding.role}-${member}"
        }
      ]
    ]
  ])

  # ----------------------------------------------------------------------------
  # Projects Map
  # ----------------------------------------------------------------------------
  # Converts the project list into a key-value map indexed by project name
  projects_map = { for p in lookup(local.config, "projects", []) : p.name => p }

  # ----------------------------------------------------------------------------
  # Project APIs
  # ----------------------------------------------------------------------------
  # Flattens list of GCP APIs to enable across all projects
  project_apis_flat = flatten([
    for proj_name, p in local.projects_map : [
      for api in lookup(p, "apis", []) : {
        project_name = proj_name
        api          = api
        key          = "${proj_name}-${api}"
      }
    ]
  ])

  # ----------------------------------------------------------------------------
  # Project-Level IAM (Users, Groups & External Identities)
  # ----------------------------------------------------------------------------
  # Flattens project-level IAM member bindings with optional CEL conditions
  project_iam_flat = flatten([
    for proj_name, p in local.projects_map : [
      for binding in lookup(p, "iam", []) : [
        for member in binding.members : {
          project_name = proj_name
          role         = binding.role
          member       = member
          condition    = lookup(binding, "condition", null)
          key          = "${proj_name}-${binding.role}-${member}"
        }
      ]
    ]
  ])

  # ----------------------------------------------------------------------------
  # Custom Workload Service Accounts
  # ----------------------------------------------------------------------------
  # Flattens custom service account definitions per project
  custom_sas_flat = flatten([
    for proj_name, p in local.projects_map : [
      for sa in lookup(p, "custom_service_accounts", []) : {
        project_name = proj_name
        account_id   = sa.account_id
        display_name = lookup(sa, "display_name", sa.account_id)
        roles        = lookup(sa, "roles", [])
        key          = "${proj_name}-${sa.account_id}"
      }
    ]
  ])

  # ----------------------------------------------------------------------------
  # Custom Service Account IAM Roles
  # ----------------------------------------------------------------------------
  # Flattens individual role grants assigned to each custom service account
  custom_sa_roles_flat = flatten([
    for sa in local.custom_sas_flat : [
      for r in sa.roles : {
        project_name = sa.project_name
        account_id   = sa.account_id
        role         = r
        key          = "${sa.project_name}-${sa.account_id}-${r}"
      }
    ]
  ])
}

# ==============================================================================
# Project Unique ID Suffix Generator
# ==============================================================================
# Generates a pseudo-random 4-character lowercase alphanumeric string per project
# to ensure global uniqueness of GCP Project IDs when 'random_id' is enabled (default: true).
resource "random_string" "project_suffix" {
  for_each = { for k, v in local.projects_map : k => v if lookup(v, "random_id", true) }
  length   = 4
  special  = false
  upper    = false
}
