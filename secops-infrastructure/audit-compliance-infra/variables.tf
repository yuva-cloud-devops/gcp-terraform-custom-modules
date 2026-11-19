# ==============================================================================
# AUDIT & COMPLIANCE INFRASTRUCTURE: INPUT VARIABLES
# ==============================================================================

variable "config_file_path" {
  description = "Path to the YAML configuration file defining Data Access audit policies, log sinks, storage destinations, and security metrics."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Raw YAML string content. If provided, overrides config_file_path."
  type        = string
  default     = null
}
