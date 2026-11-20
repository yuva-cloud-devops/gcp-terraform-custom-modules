# ==============================================================================
# Variables: PKI & Data Security Infrastructure Module
# ==============================================================================

variable "config_file_path" {
  type        = string
  description = "Path to the YAML configuration file for PKI, Certificate Manager, and DLP infrastructure."
  default     = null
}

variable "yaml_content" {
  type        = string
  description = "Direct YAML content string. If provided, overrides config_file_path."
  default     = null
}
