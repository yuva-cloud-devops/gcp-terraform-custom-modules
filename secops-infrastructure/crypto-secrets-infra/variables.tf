# ==============================================================================
# CRYPTO & SECRETS INFRASTRUCTURE: INPUT VARIABLES
# ==============================================================================

variable "config_file_path" {
  description = "Path to the YAML configuration file defining Cloud KMS keyrings, crypto keys, secret manager secrets, and IAM policies."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Raw YAML string content. If provided, overrides config_file_path."
  type        = string
  default     = null
}
