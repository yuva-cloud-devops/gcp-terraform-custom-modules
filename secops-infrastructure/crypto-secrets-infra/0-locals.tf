# ==============================================================================
# 0. Local Values & Data Transformation Pipeline
# ==============================================================================
# Parses the input YAML configuration file and flattens Cloud KMS keyrings,
# crypto keys, IAM bindings, Secret Manager secrets, replication strategies,
# versions, and access policies into deterministic collections for 'for_each'.
# ==============================================================================

locals {
  # ----------------------------------------------------------------------------
  # Raw Configuration Input (File Path or Raw Content)
  # ----------------------------------------------------------------------------
  raw_config = yamldecode(
    var.yaml_content != null ? var.yaml_content : (
      var.config_file_path != null ? file(var.config_file_path) : "{}"
    )
  )

  # Top-level global defaults
  default_project_id = try(local.raw_config.project_id, null)
  default_location   = try(local.raw_config.default_location, local.raw_config.location, "asia-south1")
  common_labels      = try(local.raw_config.common_labels, {})

  # ----------------------------------------------------------------------------
  # 1. Cloud KMS Keyrings
  # ----------------------------------------------------------------------------
  raw_keyrings = try(
    local.raw_config.kms.keyrings,
    local.raw_config.keyrings,
    []
  )

  kms_keyrings = {
    for kr in local.raw_keyrings : kr.name => {
      name       = kr.name
      location   = try(kr.location, local.default_location)
      project_id = try(kr.project_id, local.default_project_id)
    }
  }

  # ----------------------------------------------------------------------------
  # 2. Cloud KMS Crypto Keys
  # ----------------------------------------------------------------------------
  kms_keys = merge(concat([
    for kr in local.raw_keyrings : {
      for k in try(kr.keys, []) : "${kr.name}/${k.name}" => {
        composite_key                 = "${kr.name}/${k.name}"
        keyring_key                   = kr.name
        keyring_name                  = kr.name
        keyring_location              = try(kr.location, local.default_location)
        project_id                    = try(k.project_id, kr.project_id, local.default_project_id)
        name                          = k.name
        purpose                       = upper(try(k.purpose, "ENCRYPT_DECRYPT"))
        rotation_period               = try(k.rotation_period, null)
        destroy_scheduled_duration    = try(k.destroy_scheduled_duration, null)
        skip_initial_version_creation = try(k.skip_initial_version_creation, false)
        labels                        = merge(local.common_labels, try(k.labels, {}))
        version_template = try(k.version_template, null) != null ? {
          algorithm        = try(k.version_template.algorithm, "GOOGLE_SYMMETRIC_ENCRYPTION")
          protection_level = upper(try(k.version_template.protection_level, "SOFTWARE"))
        } : null
      }
    }
  ], [{}]))

  # Deterministic resource IDs (projects/{project}/locations/{location}/keyRings/{keyring}/cryptoKeys/{key})
  kms_key_resource_ids = {
    for composite_key, k in local.kms_keys :
    composite_key => "projects/${k.project_id}/locations/${k.keyring_location}/keyRings/${k.keyring_name}/cryptoKeys/${k.name}"
  }

  # Short name lookup (key_name => resource ID)
  kms_key_resource_ids_by_name = {
    for composite_key, k in local.kms_keys :
    k.name => "projects/${k.project_id}/locations/${k.keyring_location}/keyRings/${k.keyring_name}/cryptoKeys/${k.name}"
  }

  # ----------------------------------------------------------------------------
  # 3. Cloud KMS IAM Bindings
  # ----------------------------------------------------------------------------
  # Keyring-level IAM members
  kms_keyring_iam_flat = {
    for item in flatten([
      for kr in local.raw_keyrings : [
        for b in try(kr.iam, []) : [
          for m in try(b.members, []) : {
            key         = "${kr.name}--${replace(b.role, "/", "_")}--${replace(m, ":", "_")}"
            keyring_key = kr.name
            role        = b.role
            member      = m
            condition   = try(b.condition, null)
          }
        ]
      ]
    ]) : item.key => item
  }

  # CryptoKey-level IAM members
  kms_key_iam_flat = {
    for item in flatten([
      for kr in local.raw_keyrings : [
        for k in try(kr.keys, []) : [
          for b in try(k.iam, []) : [
            for m in try(b.members, []) : {
              key               = "${kr.name}--${k.name}--${replace(b.role, "/", "_")}--${replace(m, ":", "_")}"
              key_composite_key = "${kr.name}/${k.name}"
              role              = b.role
              member            = m
              condition         = try(b.condition, null)
            }
          ]
        ]
      ]
    ]) : item.key => item
  }

  # Project-level KMS IAM members
  kms_project_iam_flat = {
    for item in flatten([
      for b in try(local.raw_config.kms.project_iam, []) : [
        for m in try(b.members, []) : {
          key        = "${replace(b.role, "/", "_")}--${replace(m, ":", "_")}"
          project_id = try(b.project_id, local.default_project_id)
          role       = b.role
          member     = m
          condition  = try(b.condition, null)
        }
      ]
    ]) : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 4. Secret Manager Secrets
  # ----------------------------------------------------------------------------
  raw_secrets = try(
    local.raw_config.secret_manager.secrets,
    local.raw_config.secrets,
    []
  )

  secrets = {
    for s in local.raw_secrets : s.secret_id => {
      secret_id           = s.secret_id
      project_id          = try(s.project_id, local.default_project_id)
      labels              = merge(local.common_labels, try(s.labels, {}))
      annotations         = try(s.annotations, null)
      expire_time         = try(s.expire_time, null)
      ttl                 = try(s.ttl, null)
      version_destroy_ttl = try(s.version_destroy_ttl, null)

      # Replication type: 'automatic' (default) or 'user_managed'
      replication_type = lower(try(s.replication.type, s.replication.mode, "automatic"))

      # Resolve CMEK key for automatic replication (supports full ID, composite "kr/key", or short "key")
      resolved_kms_key_name = (
        try(s.replication.customer_managed_encryption.kms_key_name, s.replication.customer_managed_encryption.kms_key_ref, s.replication.kms_key_name, null) == null ? null : (
          startswith(try(s.replication.customer_managed_encryption.kms_key_name, s.replication.customer_managed_encryption.kms_key_ref, s.replication.kms_key_name), "projects/") ?
          try(s.replication.customer_managed_encryption.kms_key_name, s.replication.customer_managed_encryption.kms_key_ref, s.replication.kms_key_name) :
          lookup(
            local.kms_key_resource_ids,
            try(s.replication.customer_managed_encryption.kms_key_name, s.replication.customer_managed_encryption.kms_key_ref, s.replication.kms_key_name),
            lookup(
              local.kms_key_resource_ids_by_name,
              try(s.replication.customer_managed_encryption.kms_key_name, s.replication.customer_managed_encryption.kms_key_ref, s.replication.kms_key_name),
              try(s.replication.customer_managed_encryption.kms_key_name, s.replication.customer_managed_encryption.kms_key_ref, s.replication.kms_key_name)
            )
          )
        )
      )

      # User-managed replicas
      user_managed_replicas = [
        for r in try(s.replication.replicas, []) : {
          location = r.location
          resolved_kms_key_name = (
            try(r.customer_managed_encryption.kms_key_name, r.customer_managed_encryption.kms_key_ref, r.kms_key_name, null) == null ? null : (
              startswith(try(r.customer_managed_encryption.kms_key_name, r.customer_managed_encryption.kms_key_ref, r.kms_key_name), "projects/") ?
              try(r.customer_managed_encryption.kms_key_name, r.customer_managed_encryption.kms_key_ref, r.kms_key_name) :
              lookup(
                local.kms_key_resource_ids,
                try(r.customer_managed_encryption.kms_key_name, r.customer_managed_encryption.kms_key_ref, r.kms_key_name),
                lookup(
                  local.kms_key_resource_ids_by_name,
                  try(r.customer_managed_encryption.kms_key_name, r.customer_managed_encryption.kms_key_ref, r.kms_key_name),
                  try(r.customer_managed_encryption.kms_key_name, r.customer_managed_encryption.kms_key_ref, r.kms_key_name)
                )
              )
            )
          )
        }
      ]

      # Optional Rotation policy
      rotation = try(s.rotation, null) != null ? {
        rotation_period    = s.rotation.rotation_period
        next_rotation_time = try(s.rotation.next_rotation_time, null)
      } : null

      # Optional Topics (Pub/Sub notifications)
      topics = [
        for t in try(s.topics, []) : {
          name = try(t.name, t)
        }
      ]
    }
  }

  # ----------------------------------------------------------------------------
  # 5. Secret Manager Secret Versions
  # ----------------------------------------------------------------------------
  secret_versions = {
    for s in local.raw_secrets : s.secret_id => {
      secret_key      = s.secret_id
      enabled         = try(s.version.enabled, true)
      deletion_policy = upper(try(s.version.deletion_policy, "DELETE"))
      secret_data = try(
        try(s.version.is_secret_data_base64, false) ? base64decode(s.version.secret_data) : s.version.secret_data,
        try(file(s.version.secret_data_file), null)
      )
    }
    if try(s.version, null) != null && (
      try(s.version.secret_data, null) != null || try(s.version.secret_data_file, null) != null
    )
  }

  # ----------------------------------------------------------------------------
  # 6. Secret Manager IAM Bindings
  # ----------------------------------------------------------------------------
  # Secret-level IAM members
  secret_iam_flat = {
    for item in flatten([
      for s in local.raw_secrets : [
        for b in try(s.iam, []) : [
          for m in try(b.members, []) : {
            key        = "${s.secret_id}--${replace(b.role, "/", "_")}--${replace(m, ":", "_")}"
            secret_key = s.secret_id
            project_id = try(s.project_id, local.default_project_id)
            role       = b.role
            member     = m
            condition  = try(b.condition, null)
          }
        ]
      ]
    ]) : item.key => item
  }

  # Project-level Secret Manager IAM members
  secret_project_iam_flat = {
    for item in flatten([
      for b in try(local.raw_config.secret_manager.project_iam, []) : [
        for m in try(b.members, []) : {
          key        = "${replace(b.role, "/", "_")}--${replace(m, ":", "_")}"
          project_id = try(b.project_id, local.default_project_id)
          role       = b.role
          member     = m
          condition  = try(b.condition, null)
        }
      ]
    ]) : item.key => item
  }
}
