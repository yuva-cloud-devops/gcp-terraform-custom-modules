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
# 1. Global Static IP Reservations for GKE Gateway API / Ingress
#    (Used by kind: Gateway with GatewayClass: gke-l7-global-external-managed
#     or standard GKE Ingress)
# ------------------------------------------------------------------------------
resource "google_compute_global_address" "gateway_ips" {
  for_each = local.global_gateway_ips

  name         = each.value.name
  project      = each.value.project_id
  description  = each.value.description
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# ------------------------------------------------------------------------------
# 2. Regional Static IP Reservations for GKE Gateway API / Ingress
#    (Used by Regional External Gateway: gke-l7-regional-external-managed
#     or Regional Internal Gateway: gke-l7-rilb / gke-l7-regional-internal-managed)
# ------------------------------------------------------------------------------
resource "google_compute_address" "gateway_ips" {
  for_each = local.regional_gateway_ips

  name         = each.value.name
  project      = each.value.project_id
  region       = each.value.region
  description  = each.value.description
  address_type = each.value.type == "REGIONAL_INTERNAL" ? "INTERNAL" : "EXTERNAL"
  subnetwork   = each.value.type == "REGIONAL_INTERNAL" ? each.value.subnetwork : null
  address      = each.value.address
}

# ------------------------------------------------------------------------------
# 3. Standalone Network Endpoint Groups (NEGs)
#    (For connecting GKE workloads directly to Cloud Load Balancers)
# ------------------------------------------------------------------------------
resource "google_compute_network_endpoint_group" "negs" {
  for_each = local.standalone_negs

  name                  = each.value.name
  project               = each.value.project_id
  zone                  = each.value.zone
  network               = each.value.network
  subnetwork            = each.value.subnetwork
  network_endpoint_type = each.value.network_endpoint_type
  default_port          = each.value.default_port
  description           = each.value.description
}

# ------------------------------------------------------------------------------
# 4. Google-Managed SSL Certificates for GKE Gateway / Ingress
# ------------------------------------------------------------------------------
resource "google_compute_managed_ssl_certificate" "gateway_certs" {
  for_each = {
    for k, v in local.managed_ssl_certificates : k => v
    if length(v.domains) > 0
  }

  name        = each.value.name
  project     = each.value.project_id
  description = each.value.description

  managed {
    domains = each.value.domains
  }

  lifecycle {
    create_before_destroy = true
  }
}
