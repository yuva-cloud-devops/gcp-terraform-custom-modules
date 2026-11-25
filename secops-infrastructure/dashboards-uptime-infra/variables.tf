# ==============================================================================
# DASHBOARDS & UPTIME INFRASTRUCTURE: INPUT VARIABLES
# ==============================================================================

variable "config_file_path" {
  description = "Path to the YAML configuration file defining synthetic uptime checks, SSL expiry alerts, and Cloud Monitoring operational dashboards."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Raw YAML string content. If provided, overrides config_file_path."
  type        = string
  default     = null
}
