# ==============================================================================
# VPC NETWORK PEERING MODULE: INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Path to the YAML configuration file defining VPC peering topologies."
  type        = string
  default     = "./peering.yaml"
}

variable "local_network_self_link" {
  description = "Self-link or URI of the local base VPC network initiating the peering connection. Can also be declared directly in the YAML configuration."
  type        = string
  default     = ""
}

variable "peer_network_overrides" {
  description = "Optional map of peering names to peer network self-links to dynamically override values defined in the YAML file (useful when peer VPCs are created in the same Terraform execution)."
  type        = map(string)
  default     = {}
}
