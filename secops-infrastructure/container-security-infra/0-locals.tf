locals {
  # ----------------------------------------------------------------------------
  # 1. Configuration Parsing
  # ----------------------------------------------------------------------------
  raw_config = (
    var.yaml_content != null ? yamldecode(var.yaml_content) : (
      var.config_file_path != null ? yamldecode(file(var.config_file_path)) : {}
    )
  )

  cfg                = try(local.raw_config.container_security, local.raw_config)
  default_project_id = try(local.cfg.project_id, null)

  # ----------------------------------------------------------------------------
  # 2. Container Analysis (Grafeas) Notes
  # ----------------------------------------------------------------------------
  raw_notes = try(local.cfg.container_analysis_notes, {})

  notes_map = {
    for k, v in local.raw_notes : try(v.name, tostring(k)) => {
      name              = try(v.name, tostring(k))
      project_id        = try(v.project_id, local.default_project_id)
      short_description = try(v.short_description, "SecOps Container Analysis Note")
      long_description  = try(v.long_description, "Grafeas Attestation Authority Note managed by Terraform")
      hint              = try(v.hint, try(v.name, tostring(k)))
      iam_members       = try(v.iam_members, [])
    }
  }

  note_iam_members = flatten([
    for note_key, note in local.notes_map : [
      for idx, iam in note.iam_members : {
        key        = "${note.name}-${replace(iam.role, "/", "_")}-${replace(replace(iam.member, ":", "_"), "@", "_")}"
        note_name  = note.name
        project_id = note.project_id
        role       = iam.role
        member     = iam.member
      }
    ]
  ])

  note_iam_members_map = {
    for item in local.note_iam_members : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 3. Binary Authorization Attestors
  # ----------------------------------------------------------------------------
  raw_attestors = try(local.cfg.attestors, {})

  attestors_map = {
    for k, v in local.raw_attestors : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      description = try(v.description, "Binary Authorization Attestor managed by Terraform")
      note_ref    = try(v.note_ref, try(v.note_name, tostring(k)))
      public_keys = try(v.public_keys, [])
      iam_members = try(v.iam_members, [])
    }
  }

  attestor_iam_members = flatten([
    for att_key, att in local.attestors_map : [
      for idx, iam in att.iam_members : {
        key           = "${att.name}-${replace(iam.role, "/", "_")}-${replace(replace(iam.member, ":", "_"), "@", "_")}"
        attestor_name = att.name
        project_id    = att.project_id
        role          = iam.role
        member        = iam.member
      }
    ]
  ])

  attestor_iam_members_map = {
    for item in local.attestor_iam_members : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 4. Binary Authorization Policy
  # ----------------------------------------------------------------------------
  raw_policy = try(local.cfg.policy, null)

  has_policy = local.raw_policy != null

  policy_config = local.has_policy ? {
    project_id                    = try(local.raw_policy.project_id, local.default_project_id)
    description                   = try(local.raw_policy.description, "SecOps Binary Authorization Policy")
    global_policy_evaluation_mode = try(local.raw_policy.global_policy_evaluation_mode, "ENABLE")
    admission_whitelist_patterns  = try(local.raw_policy.admission_whitelist_patterns, [
      "gcr.io/google_containers/*",
      "k8s.gcr.io/*",
      "gke.gcr.io/*",
      "gcr.io/stackdriver-agents/*"
    ])
    default_admission_rule = {
      evaluation_mode  = try(local.raw_policy.default_admission_rule.evaluation_mode, "ALWAYS_ALLOW")
      enforcement_mode = try(local.raw_policy.default_admission_rule.enforcement_mode, "DRYRUN_AUDIT_LOG_ONLY")
      require_attestations_by = [
        for att in try(local.raw_policy.default_admission_rule.require_attestations_by, []) : (
          startswith(att, "projects/") ? att : "projects/${try(local.raw_policy.project_id, local.default_project_id)}/attestors/${att}"
        )
      ]
    }
    cluster_admission_rules = {
      for c_key, c_val in try(local.raw_policy.cluster_admission_rules, {}) : c_key => {
        cluster          = try(c_val.cluster, tostring(c_key))
        evaluation_mode  = try(c_val.evaluation_mode, "REQUIRE_ATTESTATION")
        enforcement_mode = try(c_val.enforcement_mode, "DRYRUN_AUDIT_LOG_ONLY")
        require_attestations_by = [
          for att in try(c_val.require_attestations_by, []) : (
            startswith(att, "projects/") ? att : "projects/${try(local.raw_policy.project_id, local.default_project_id)}/attestors/${att}"
          )
        ]
      }
    }
  } : null
}
