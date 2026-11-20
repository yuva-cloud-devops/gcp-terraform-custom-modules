# ==============================================================================
# Variables: Threat Posture Infrastructure (SCC & Cloud Asset Inventory)
# ==============================================================================

variable "config_file_path" {
  description = "Path to the YAML configuration file defining threat posture, SCC notification configs, BigQuery exports, and Cloud Asset Inventory feeds."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Raw YAML string content defining threat posture rules. Takes precedence over config_file_path if provided."
  type        = string
  default     = null
}
