terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0, < 7.0.0"
    }
  }
}

provider "google" {
  project = "yuvaraj-internal-project"
  region  = "asia-south1"
}

module "container_infrastructure" {
  source = "../../container-infrastructure"

  config_file_path = "${path.module}/container-infrastructure.yaml"
}

output "artifact_registries" {
  description = "Artifact Registry repositories"
  value       = module.container_infrastructure.artifact_registries
}

output "gke_clusters" {
  description = "GKE clusters endpoints and connection commands"
  value       = module.container_infrastructure.gke_clusters
}

output "gke_node_pools" {
  description = "GKE node pools"
  value       = module.container_infrastructure.gke_node_pools
}

output "gateway_ip_reservations" {
  description = "Reserved static IPs for Gateway API"
  value       = module.container_infrastructure.gateway_ip_reservations
}

output "standalone_negs" {
  description = "Standalone NEGs for Load Balancing"
  value       = module.container_infrastructure.standalone_negs
}

output "container_summary" {
  description = "Summary of container platform resources"
  value       = module.container_infrastructure.container_summary
}
