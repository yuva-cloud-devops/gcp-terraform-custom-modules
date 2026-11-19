variable "config_file_path" {
  description = "The path to the YAML configuration file defining Edge Security, Cloud Armor, Cloud IDS, and VPC SC."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Raw YAML string content defining Edge Security configuration. Useful for inline testing or dynamic templates."
  type        = string
  default     = null

  validation {
    condition     = var.config_file_path != null || var.yaml_content != null
    error_message = "Either 'config_file_path' or 'yaml_content' must be provided."
  }
}
