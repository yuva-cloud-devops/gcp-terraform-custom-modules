# ==============================================================================
# Container Analysis (Grafeas) Notes & IAM
# ==============================================================================

resource "google_container_analysis_note" "notes" {
  for_each = local.notes_map

  name              = each.value.name
  project           = each.value.project_id
  short_description = each.value.short_description
  long_description  = each.value.long_description

  attestation_authority {
    hint {
      human_readable_name = each.value.hint
    }
  }
}

resource "google_container_analysis_note_iam_member" "note_iam" {
  for_each = local.note_iam_members_map

  project = each.value.project_id
  note    = try(google_container_analysis_note.notes[each.value.note_name].name, each.value.note_name)
  role    = each.value.role
  member  = each.value.member
}
