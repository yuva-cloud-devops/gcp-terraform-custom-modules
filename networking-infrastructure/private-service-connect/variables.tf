# ==============================================================================
# PRIVATE SERVICE CONNECT (PSC) MODULE: INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Filesystem path to the YAML file defining Private Service Connect endpoints and targets."
  type        = string
  default     = "./psc.yaml"
}

variable "project_id" {
  description = "GCP Project ID where PSC endpoints are provisioned (can also be declared directly in YAML)."
  type        = string
  default     = null
}

variable "network_self_link" {
  description = "Self-link or URL of the VPC network to attach PSC endpoints to (can also be declared directly in YAML)."
  type        = string
  default     = null
}
