output "container_analysis_notes" {
  description = "Created Container Analysis notes"
  value       = module.container_security.container_analysis_notes
}

output "attestors" {
  description = "Created Binary Authorization attestors"
  value       = module.container_security.attestors
}

output "policy" {
  description = "Created Binary Authorization policy"
  value       = module.container_security.policy
}
