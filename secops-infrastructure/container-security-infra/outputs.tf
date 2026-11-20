# ==============================================================================
# Outputs: Container Security Infrastructure
# ==============================================================================

output "container_analysis_notes" {
  description = "Created Container Analysis Grafeas notes."
  value = {
    for k, v in google_container_analysis_note.notes : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "attestors" {
  description = "Created Binary Authorization attestors."
  value = {
    for k, v in google_binary_authorization_attestor.attestors : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "policy" {
  description = "Created or updated Binary Authorization policy."
  value = local.has_policy && length(google_binary_authorization_policy.policy) > 0 ? {
    id                            = google_binary_authorization_policy.policy[0].id
    global_policy_evaluation_mode = google_binary_authorization_policy.policy[0].global_policy_evaluation_mode
  } : null
}
