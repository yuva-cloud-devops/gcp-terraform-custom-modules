# ==============================================================================
# SHARED VPC MODULE INPUT VARIABLES
# ==============================================================================

variable "yaml_config_path" {
  description = "Path to the Shared VPC YAML configuration file defining host project, service projects, allowed subnets, and subnet IAM bindings."
  type        = string
  default     = "./shared_vpc.yaml"
}
