# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the input YAML configuration file and flattens nested data structures
# (Organization IAM, folder hierarchy, cryptographic tags, projects, APIs, IAM
# bindings, custom service accounts, and tag bindings) into map/list collections
# suitable for Terraform 'for_each' iteration.
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
  # Folders Lookup Map
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
  # Resource Tag Values (Organization Level)
  # ----------------------------------------------------------------------------
  # Flattens tag keys and their allowed values for organization tag management
  tag_values_flat = flatten([
    for t in lookup(local.config, "tags", []) : [
      for val in t.values : {
        tag_key = t.key
        value   = val
        key     = "${t.key}/${val}"
      }
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

  # ----------------------------------------------------------------------------
  # Project Cryptographic Tag Bindings
  # ----------------------------------------------------------------------------
  # Flattens tag bindings assigned to projects for ABAC and governance policies
  project_tag_bindings_flat = flatten([
    for proj_name, p in local.projects_map : [
      for tag_str in lookup(p, "tag_bindings", []) : {
        project_name = proj_name
        tag_key_val  = tag_str
        key          = "${proj_name}-${tag_str}"
      }
    ]
  ])
}
