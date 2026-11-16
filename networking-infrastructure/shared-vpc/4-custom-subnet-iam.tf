# ==============================================================================
# 4. Subnet-Level IAM Delegations (Least-Privilege Network User)
# ==============================================================================
# Grants 'roles/compute.networkUser' on specific host project subnetworks to:
# 1. Google APIs Service Agent (Instance/MIG creation)
# 2. GKE Service Agent (Node and Pod secondary range attachment)
# 3. Cloud Run / Serverless Robot (Direct VPC egress)
# 4. Custom users, developer groups, and CI/CD deployment service accounts
#
# Enforces strict least privilege by scoping network access to designated subnets
# rather than granting project-wide network access.
# ==============================================================================

resource "google_compute_subnetwork_iam_member" "subnet_network_user" {
  for_each = { for item in local.all_subnet_bindings : item.key => item }

  project    = local.host_project_id
  region     = each.value.region
  subnetwork = each.value.subnet_name
  role       = "roles/compute.networkUser"
  member     = each.value.member

  depends_on = [google_compute_shared_vpc_host_project.host]
}
