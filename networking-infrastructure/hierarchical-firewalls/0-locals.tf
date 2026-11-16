# ==============================================================================
# HIERARCHICAL FIREWALL MODULE: LOCAL CONFIGURATION & RESOLUTION
# ==============================================================================
# Decodes the declarative YAML firewall configuration file and derives target
# resource strings, policy parameters, and deterministic rule mappings.
# ==============================================================================

locals {
  # Decode input YAML configuration file into a structured HCL map
  config = yamldecode(file(var.yaml_config_path))

  # Resolve parent resource URI based on parent_type:
  # - "organization" -> "organizations/123456789012"
  # - "folder"       -> "folders/123456789012"
  parent_target = (
    lookup(local.config, "parent_type", "folder") == "organization" ?
    "organizations/${local.config.parent_id}" :
    "folders/${local.config.parent_id}"
  )

  # Map rules by unique priority string to guarantee deterministic Terraform state keys
  rules_map = {
    for r in lookup(local.config, "rules", []) : tostring(r.priority) => r
  }
}

