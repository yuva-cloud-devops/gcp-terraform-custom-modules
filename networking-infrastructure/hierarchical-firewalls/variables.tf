# ==============================================================================
# HIERARCHICAL FIREWALL MODULE: INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Filesystem path to the YAML file defining hierarchical firewall policies, rules, and associations."
  type        = string
  default     = "./firewalls.yaml"
}

