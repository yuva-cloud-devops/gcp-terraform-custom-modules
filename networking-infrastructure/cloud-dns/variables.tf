# ==============================================================================
# CLOUD DNS MODULE: INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Filesystem path to the YAML file defining Cloud DNS zones and records."
  type        = string
  default     = "./dns.yaml"
}

variable "project_id" {
  description = "GCP Project ID where Cloud DNS zones will be provisioned (can also be declared directly in YAML)."
  type        = string
  default     = null
}

variable "network_self_link" {
  description = "Single VPC network self_link or URL to bind private DNS zones to (optional if declared in YAML or network_self_links)."
  type        = string
  default     = null
}

variable "network_self_links" {
  description = "List of VPC network self_links or URLs to bind private DNS zones to (optional if declared in YAML)."
  type        = list(string)
  default     = []
}
