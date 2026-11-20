# ==============================================================================
# Binary Authorization Attestors & IAM
# ==============================================================================

resource "google_binary_authorization_attestor" "attestors" {
  for_each = local.attestors_map

  name        = each.value.name
  project     = each.value.project_id
  description = each.value.description

  attestation_authority_note {
    note_reference = (
      startswith(each.value.note_ref, "projects/") ?
      each.value.note_ref :
      try(google_container_analysis_note.notes[each.value.note_ref].name, "projects/${each.value.project_id}/notes/${each.value.note_ref}")
    )

    dynamic "public_keys" {
      for_each = each.value.public_keys
      content {
        id                           = try(public_keys.value.id, null)
        comment                      = try(public_keys.value.comment, null)
        ascii_armored_pgp_public_key = try(public_keys.value.ascii_armored_pgp_public_key, null)

        dynamic "pkix_public_key" {
          for_each = try(public_keys.value.pkix_public_key, null) != null ? [public_keys.value.pkix_public_key] : []
          content {
            public_key_pem      = try(pkix_public_key.value.public_key_pem, null)
            signature_algorithm = try(pkix_public_key.value.signature_algorithm, null)
          }
        }
      }
    }
  }

  depends_on = [
    google_container_analysis_note.notes
  ]
}

resource "google_binary_authorization_attestor_iam_member" "attestor_iam" {
  for_each = local.attestor_iam_members_map

  project  = each.value.project_id
  attestor = try(google_binary_authorization_attestor.attestors[each.value.attestor_name].name, each.value.attestor_name)
  role     = each.value.role
  member   = each.value.member
}
