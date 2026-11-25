# ==============================================================================
# MONITORING & ALERTING INFRASTRUCTURE: INPUT VARIABLES
# ==============================================================================

variable "config_file_path" {
  description = "Path to the YAML configuration file defining multi-project metric scopes, notification channels, CIS benchmark alerts, and metric threshold policies."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Raw YAML string content. If provided, overrides config_file_path."
  type        = string
  default     = null
}
