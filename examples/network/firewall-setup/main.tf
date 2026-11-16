# ==============================================================================
# HIERARCHICAL FIREWALL GUARDRAILS EXAMPLE
# ==============================================================================
# Demonstrates provisioning centralized hierarchical firewall policies and
# rules attached at the Folder or Organization level using declarative YAML.
# ==============================================================================

module "hierarchical_firewalls" {
  source           = "../../../networking-infrastructure/hierarchical-firewalls"
  yaml_config_path = "${path.module}/firewalls.yaml"
}

