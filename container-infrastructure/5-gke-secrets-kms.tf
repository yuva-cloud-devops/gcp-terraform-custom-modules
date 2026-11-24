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
# 0. GCP Project Data (Required for GKE Robot Service Account Number)
# ------------------------------------------------------------------------------
data "google_project" "project" {
  for_each = toset(distinct(compact([
    for c in local.clusters : c.project_id
  ])))
  project_id = each.value
}

# ------------------------------------------------------------------------------
# 1. Cloud KMS IAM Attachment for Application-Layer Secrets Encryption
#    (Grants GKE Robot SA Encrypter/Decrypter permissions on the EXTERNAL KMS key)
# ------------------------------------------------------------------------------
resource "google_kms_crypto_key_iam_member" "gke_robot_encryption" {
  for_each = local.clusters_with_kms

  crypto_key_id = each.value.database_encryption_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project[each.value.project_id].number}@container-engine-robot.iam.gserviceaccount.com"
}

# ------------------------------------------------------------------------------
# 2. Secret Manager Workload Identity Access (Direct KSA Binding)
#    Grants Kubernetes Pods (KSA) read access to existing Secret Manager secrets
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_member" "direct_ksa_accessor" {
  for_each = {
    for item in local.secret_workload_access_bindings : item.key => item
  }

  project   = each.value.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.workload_pool}[${each.value.namespace}/${each.value.service_account}]"
}

# ------------------------------------------------------------------------------
# 3. Dedicated Workload Service Accounts (GSA <-> KSA Mapping)
# ------------------------------------------------------------------------------
resource "google_service_account" "workload_sas" {
  for_each = local.workload_service_accounts

  account_id   = each.value.account_id
  project      = each.value.project_id
  display_name = each.value.display_name
  description  = each.value.description
}

resource "google_project_iam_member" "workload_sa_roles" {
  for_each = {
    for item in local.workload_sa_project_roles : item.key => item
  }

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.workload_sas[each.value.sa_key].email}"
}

# Workload Identity User Binding (Authorizes KSA to act as GSA)
resource "google_service_account_iam_member" "workload_identity_user" {
  for_each = {
    for item in local.workload_sa_k8s_bindings : item.key => item
  }

  service_account_id = google_service_account.workload_sas[each.value.sa_key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${each.value.project_id}.svc.id.goog[${each.value.namespace}/${each.value.service_account}]"
}
