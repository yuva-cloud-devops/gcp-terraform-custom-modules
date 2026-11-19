# ==============================================================================
# INPUT VARIABLES: Zero-Trust Security Infrastructure (IAP & WIF)
# ==============================================================================

variable "config_file_path" {
  description = "Path to the YAML configuration file containing Zero Trust Security specifications."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Direct YAML content as a string. Overrides 'config_file_path' if provided."
  type        = string
  default     = null
}
