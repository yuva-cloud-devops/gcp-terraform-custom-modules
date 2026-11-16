# ==============================================================================
# 2. Service Project Attachment
# ==============================================================================
# Dynamically associates workload and application service projects with the
# Shared VPC Host Project. Service projects can deploy workloads (GCE, GKE, Cloud Run)
# that attach to the host project's network without managing their own network topology.
# ==============================================================================

resource "google_compute_shared_vpc_service_project" "service_projects" {
  for_each = local.service_projects

  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = each.value.project_id
}
