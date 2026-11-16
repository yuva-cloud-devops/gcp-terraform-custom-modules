# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the input YAML configuration file and constructs flattened IAM binding
# collections for Shared VPC service agents, workload robots, and custom members.
#
# Generates least-privilege 'roles/compute.networkUser' bindings on specific subnets
# for:
# 1. Google APIs Service Agent (<PROJECT_NUMBER>@cloudservices.gserviceaccount.com)
# 2. GKE Container Engine Robot (service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com)
# 3. Cloud Run / Serverless Robot (service-<PROJECT_NUMBER>@serverless-robot-prod.iam.gserviceaccount.com)
# 4. Custom users, developer groups, and CI/CD deployment service accounts
# ==============================================================================

locals {
  # Parse and decode the YAML configuration file
  config = yamldecode(file(var.yaml_config_path))

  # Host Project Identifier
  host_project_id = local.config.host_project_id

  # Keyed map of service projects for iteration
  service_projects = {
    for p in lookup(local.config, "service_projects", []) : p.project_id => p
  }

  # ----------------------------------------------------------------------------
  # 1. Google APIs Service Agent (Compute Engine & Instance Group Management)
  # ----------------------------------------------------------------------------
  # Identity: <PROJECT_NUMBER>@cloudservices.gserviceaccount.com
  # Grants 'roles/compute.networkUser' on each allowed subnet so the service
  # project can provision Compute Engine instances and Managed Instance Groups (MIGs).
  cloudservices_robots = flatten([
    for p in local.service_projects : [
      for s in lookup(p, "allowed_subnets", []) : {
        subnet_name = s.name
        region      = s.region
        member      = "serviceAccount:${p.project_number}@cloudservices.gserviceaccount.com"
        key         = "${s.name}-${s.region}-${p.project_id}-cloudservices"
      }
    ]
  ])

  # ----------------------------------------------------------------------------
  # 2. GKE Container Engine Robot (Kubernetes Engine Workloads)
  # ----------------------------------------------------------------------------
  # Identity: service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com
  # Grants 'roles/compute.networkUser' on each allowed subnet when 'enable_gke: true'
  # so GKE can attach cluster nodes and consume secondary Pod/Service CIDR ranges.
  gke_robots = flatten([
    for p in local.service_projects : [
      for s in lookup(p, "allowed_subnets", []) : {
        subnet_name = s.name
        region      = s.region
        member      = "serviceAccount:service-${p.project_number}@container-engine-robot.iam.gserviceaccount.com"
        key         = "${s.name}-${s.region}-${p.project_id}-gke"
      }
    ] if lookup(p, "enable_gke", false)
  ])

  # ----------------------------------------------------------------------------
  # 3. Cloud Run / Serverless VPC Access Robot (Direct VPC Egress)
  # ----------------------------------------------------------------------------
  # Identity: service-<PROJECT_NUMBER>@serverless-robot-prod.iam.gserviceaccount.com
  # Grants 'roles/compute.networkUser' on each allowed subnet when 'enable_cloud_run: true'
  # so Cloud Run services and Serverless VPC Connectors can route egress traffic.
  cloud_run_robots = flatten([
    for p in local.service_projects : [
      for s in lookup(p, "allowed_subnets", []) : {
        subnet_name = s.name
        region      = s.region
        member      = "serviceAccount:service-${p.project_number}@serverless-robot-prod.iam.gserviceaccount.com"
        key         = "${s.name}-${s.region}-${p.project_id}-cloudrun"
      }
    ] if lookup(p, "enable_cloud_run", false)
  ])

  # ----------------------------------------------------------------------------
  # 4. Custom User, Group & CI/CD Pipeline Subnet IAM
  # ----------------------------------------------------------------------------
  # Grants 'roles/compute.networkUser' on specific subnets to developers,
  # operations groups, and deployment service accounts defined in 'custom_subnet_iam'.
  custom_subnet_members = flatten([
    for entry in lookup(local.config, "custom_subnet_iam", []) : [
      for m in lookup(entry, "members", []) : {
        subnet_name = entry.subnet_name
        region      = entry.region
        member      = m
        key         = "${entry.subnet_name}-${entry.region}-${m}"
      }
    ]
  ])

  # ----------------------------------------------------------------------------
  # Consolidated Subnet IAM Delegations
  # ----------------------------------------------------------------------------
  # Combines all automated service agent robots and custom member delegations
  # into a single unified list for iteration by google_compute_subnetwork_iam_member.
  all_subnet_bindings = concat(
    local.cloudservices_robots,
    local.gke_robots,
    local.cloud_run_robots,
    local.custom_subnet_members
  )
}
