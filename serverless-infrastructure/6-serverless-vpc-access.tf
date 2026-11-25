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

# ------------------------------------------------------------------------------
# Serverless VPC Access Connectors (Legacy Fallback Support)
# Note: Google Cloud strongly recommends Direct VPC Egress (configured in
# 1-cloud-run-services.tf and 2-cloud-run-jobs.tf via network_interfaces)
# which provides zero-cost connector-less networking with up to 100 Gbps.
# This resource is available for architectures requiring a dedicated connector.
# ------------------------------------------------------------------------------
resource "google_vpc_access_connector" "connectors" {
  for_each = local.serverless_vpc_connectors

  name          = each.value.name
  project       = each.value.project_id
  region        = each.value.region
  network       = each.value.subnet_name == null ? each.value.network : null
  ip_cidr_range = each.value.subnet_name == null ? each.value.ip_cidr_range : null

  dynamic "subnet" {
    for_each = each.value.subnet_name != null ? [1] : []
    content {
      name       = each.value.subnet_name
      project_id = each.value.project_id
    }
  }

  machine_type  = each.value.machine_type
  min_instances = each.value.min_instances
  max_instances = each.value.max_instances
}
