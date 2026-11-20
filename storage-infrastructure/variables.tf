variable "config_file_path" {
  description = "Path to the YAML configuration file containing storage infrastructure specifications."
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Direct YAML content string. If provided, overrides config_file_path."
  type        = string
  default     = null
}
