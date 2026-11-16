# ==============================================================================
# HA CLOUD VPN MODULE: INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Path to the YAML configuration file defining HA Cloud VPN topology."
  type        = string
  default     = "./vpn.yaml"
}

variable "network_self_link" {
  description = "Self-link or URI of the target VPC network. Can also be defined directly in the YAML configuration."
  type        = string
  default     = ""
}

variable "project_id" {
  description = "Target GCP project ID. If omitted, falls back to project_id in the YAML file."
  type        = string
  default     = ""
}

variable "default_region" {
  description = "Default GCP region for HA VPN gateways and tunnels. If omitted, falls back to default_region in the YAML file."
  type        = string
  default     = ""
}

variable "router_name" {
  description = "Name of the target Cloud Router to bind VPN interfaces and BGP peers. If omitted, falls back to default_router_name in the YAML file."
  type        = string
  default     = ""
}
