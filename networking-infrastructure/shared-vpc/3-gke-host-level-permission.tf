# ==============================================================================
# 3. GKE Host Service Agent Permissions (Host-Level IAM)
# ==============================================================================
# Grants the GKE Service Agent of each service project the 'roles/container.hostServiceAgentUser'
# role at the HOST PROJECT level when 'enable_gke: true' is configured.
#
# This permission is required by GCP so that the service project's GKE control plane
# can configure firewall rules, routes, and network resources in the Shared VPC host project.
# ==============================================================================

resource "google_project_iam_member" "gke_host_service_agent" {
  for_each = {
    for k, p in local.service_projects : k => p if lookup(p, "enable_gke", false)
  }

  project = local.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:service-${each.value.project_number}@container-engine-robot.iam.gserviceaccount.com"

  depends_on = [google_compute_shared_vpc_service_project.service_projects]
}
