# ==============================================================================
# 2. WIF Dedicated Service Accounts & Impersonation Bindings
# ==============================================================================
# Declares dedicated Service Accounts for external CI/CD pipelines (GitHub Actions,
# GitLab CI, AWS, etc.) and binds 'roles/iam.workloadIdentityUser' to federated
# external identities or groups without any static JSON credentials.
# ==============================================================================

# ------------------------------------------------------------------------------
# Managed Workload Identity Service Accounts
# ------------------------------------------------------------------------------
resource "google_service_account" "wif_sa" {
  for_each = local.service_accounts_map

  account_id   = each.value.account_id
  project      = each.value.project_id
  display_name = each.value.display_name
  description  = each.value.description
}

# ------------------------------------------------------------------------------
# Project Roles Granted to WIF Service Accounts
# ------------------------------------------------------------------------------
resource "google_project_iam_member" "sa_project_roles" {
  for_each = local.sa_roles_map

  project = each.value.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.wif_sa[each.value.account_id].email}"

  depends_on = [
    google_service_account.wif_sa
  ]
}

# ------------------------------------------------------------------------------
# Workload Identity Impersonation Bindings (roles/iam.workloadIdentityUser)
# ------------------------------------------------------------------------------
resource "google_service_account_iam_member" "wif_impersonation" {
  for_each = local.sa_wif_bindings_map

  service_account_id = google_service_account.wif_sa[each.value.account_id].name
  role               = "roles/iam.workloadIdentityUser"

  # Resolves pool name to fully-qualified principal / principalSet URI
  member = (
    each.value.attribute == "all" || each.value.attribute == "*" ?
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.pools[each.value.pool_key].name}/*" : (
      startswith(each.value.attribute, "principal://") || startswith(each.value.attribute, "principalSet://") ?
      each.value.attribute : (
        startswith(each.value.attribute, "subject/") ?
        "principal://iam.googleapis.com/${google_iam_workload_identity_pool.pools[each.value.pool_key].name}/${each.value.attribute}" :
        "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.pools[each.value.pool_key].name}/${each.value.attribute}"
      )
    )
  )

  depends_on = [
    google_service_account.wif_sa,
    google_iam_workload_identity_pool.pools,
    google_iam_workload_identity_pool_provider.providers
  ]
}
