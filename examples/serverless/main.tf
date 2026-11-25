terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0, < 7.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0, < 7.0.0"
    }
  }
}

provider "google" {
  project = "yuvaraj-internal-project"
  region  = "asia-south1"
}

provider "google-beta" {
  project = "yuvaraj-internal-project"
  region  = "asia-south1"
}

module "serverless_infrastructure" {
  source = "../../serverless-infrastructure"

  config_file_path = "${path.module}/serverless-infrastructure.yaml"
}

output "cloud_run_services" {
  description = "Cloud Run v2 Services details and URLs"
  value       = module.serverless_infrastructure.cloud_run_services
}

output "cloud_run_jobs" {
  description = "Cloud Run v2 Jobs and execution commands"
  value       = module.serverless_infrastructure.cloud_run_jobs
}

output "cloud_functions" {
  description = "Cloud Functions 2nd Gen details and URIs"
  value       = module.serverless_infrastructure.cloud_functions
}

output "cloud_workflows" {
  description = "Cloud Workflows state machines"
  value       = module.serverless_infrastructure.cloud_workflows
}

output "eventarc_triggers" {
  description = "Eventarc triggers"
  value       = module.serverless_infrastructure.eventarc_triggers
}

output "cloud_tasks_queues" {
  description = "Cloud Tasks async queues"
  value       = module.serverless_infrastructure.cloud_tasks_queues
}

output "cloud_scheduler_jobs" {
  description = "Cloud Scheduler cron jobs"
  value       = module.serverless_infrastructure.cloud_scheduler_jobs
}

output "serverless_summary" {
  description = "Summary of serverless platform resources"
  value       = module.serverless_infrastructure.serverless_summary
}
