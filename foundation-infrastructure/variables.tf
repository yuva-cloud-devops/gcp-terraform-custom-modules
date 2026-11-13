# ==============================================================================
# FOUNDATION INFRASTRUCTURE INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Path to the hierarchy YAML configuration file defining org IAM, folder hierarchy, projects, APIs, and service accounts."
  type        = string
  default     = "./hierarchy.yaml"
}
