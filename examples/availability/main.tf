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

module "availability" {
  source = "../../availability-infrastructure"

  config_file_path = "${path.module}/availability-infrastructure.yaml"

  # In production, pass instance group links from your compute module:
  # mig_backend_groups = {
  #   "web-app-regional-mig" = module.compute.managed_instance_groups["web-app-regional-mig"].instance_group
  # }
}

output "primary_external_ip" {
  description = "Global Anycast static IPv4 address"
  value       = module.availability.primary_external_ip
}

output "availability_summary" {
  description = "Summary of provisioned resources"
  value       = module.availability.availability_summary
}
