/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "config_file_path" {
  description = "Path to the declarative YAML configuration file for availability infrastructure"
  type        = string
  default     = null
}

variable "config_content" {
  description = "Raw YAML string content for availability infrastructure (alternative to config_file_path)"
  type        = string
  default     = null
}

variable "yaml_content" {
  description = "Alternative raw YAML string content for availability infrastructure"
  type        = string
  default     = null
}

variable "mig_backend_groups" {
  description = "Optional map of Managed Instance Group self_links (e.g. { 'web-app-regional-mig' = 'projects/.../instanceGroups/...' }) to easily attach compute MIG outputs to LB backends"
  type        = map(string)
  default     = {}
}
