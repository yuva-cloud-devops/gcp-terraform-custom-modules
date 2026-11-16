# ==============================================================================
# 1. Shared VPC Host Project Enablement
# ==============================================================================
# Designates the centralized networking project as a Shared VPC Host Project.
# Allows authorized service projects to attach to this host project and consume
# centrally managed VPC networks, subnets, routers, and firewall rules.
# ==============================================================================

resource "google_compute_shared_vpc_host_project" "host" {
  project = local.host_project_id
}
