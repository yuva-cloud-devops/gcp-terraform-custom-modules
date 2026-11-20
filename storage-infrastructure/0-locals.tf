locals {
  # ----------------------------------------------------------------------------
  # 1. Configuration Parsing & Top-Level Context
  # ----------------------------------------------------------------------------
  raw_config = (
    var.yaml_content != null ? yamldecode(var.yaml_content) : (
      var.config_file_path != null ? yamldecode(file(var.config_file_path)) : {}
    )
  )

  cfg                = try(local.raw_config.storage_infrastructure, try(local.raw_config.storage, local.raw_config))
  default_project_id = try(local.cfg.project_id, null)
  default_region     = try(local.cfg.region, "asia-south1")

  # ----------------------------------------------------------------------------
  # 2. Cloud Storage (GCS) Buckets
  # ----------------------------------------------------------------------------
  raw_gcs     = try(local.cfg.gcs, {})
  raw_buckets = try(local.raw_gcs.buckets, local.raw_gcs)

  buckets_map = {
    for k, v in local.raw_buckets : try(v.name, tostring(k)) => {
      name                        = try(v.name, tostring(k))
      project_id                  = try(v.project_id, local.default_project_id)
      location                    = try(v.location, local.default_region)
      storage_class               = upper(try(v.storage_class, "STANDARD"))
      uniform_bucket_level_access = try(v.uniform_bucket_level_access, true)
      public_access_prevention    = lower(try(v.public_access_prevention, "enforced"))
      versioning                  = try(v.versioning, false)
      force_destroy               = try(v.force_destroy, false)
      autoclass                   = try(v.autoclass, null)
      kms_key_name                = try(v.kms_key_name, try(v.encryption.kms_key_name, null))
      retention_policy = try(v.retention_policy, null) != null ? {
        retention_period = try(
          v.retention_policy.retention_period_seconds,
          try(v.retention_policy.retention_period_days * 86400, try(v.retention_policy.retention_period, null))
        )
        is_locked = try(v.retention_policy.is_locked, false)
      } : null
      soft_delete_policy = try(v.soft_delete_policy, null) != null ? {
        retention_duration_seconds = try(
          v.soft_delete_policy.retention_duration_seconds,
          try(v.soft_delete_policy.retention_duration_days * 86400, null)
        )
      } : null
      cors            = try(v.cors, [])
      website         = try(v.website, null)
      lifecycle_rules = try(v.lifecycle_rules, [])
      labels          = try(v.labels, {})
      iam_members     = try(v.iam_members, [])
    } if can(v.location) || can(v.storage_class) || can(v.name) || try(v.buckets, null) == null
  }

  bucket_iam_members = flatten([
    for b_key, b in local.buckets_map : [
      for idx, iam in b.iam_members : {
        key    = "${b.name}-${replace(iam.role, "/", "_")}-${replace(replace(iam.member, ":", "_"), "@", "_")}"
        bucket = b.name
        role   = iam.role
        member = iam.member
      }
    ]
  ])

  bucket_iam_members_map = {
    for item in local.bucket_iam_members : item.key => item
  }

  # ----------------------------------------------------------------------------
  # 3. Compute Disks: Snapshot Policies
  # ----------------------------------------------------------------------------
  raw_compute_disks     = try(local.cfg.compute_disks, {})
  raw_snapshot_policies = try(local.raw_compute_disks.snapshot_policies, {})

  snapshot_policies_map = {
    for k, v in local.raw_snapshot_policies : try(v.name, tostring(k)) => {
      name                  = try(v.name, tostring(k))
      project_id            = try(v.project_id, local.default_project_id)
      region                = try(v.region, local.default_region)
      description           = try(v.description, "Disaster Recovery Snapshot Schedule managed by Terraform")
      hourly_schedule       = try(v.schedule.hourly, null)
      daily_schedule        = try(v.schedule.daily, null)
      weekly_schedule       = try(v.schedule.weekly, null)
      max_retention_days    = try(v.retention_policy.max_retention_days, 14)
      on_source_disk_delete = upper(try(v.retention_policy.on_source_disk_delete, "KEEP_SNAPSHOTS"))
      storage_locations     = try(v.snapshot_properties.storage_locations, [try(v.region, local.default_region)])
      guest_flush           = try(v.snapshot_properties.guest_flush, false)
      labels                = try(v.snapshot_properties.labels, {})
    }
  }

  # ----------------------------------------------------------------------------
  # 4. Compute Disks: Zonal Disks
  # ----------------------------------------------------------------------------
  raw_zonal_disks = try(local.raw_compute_disks.zonal_disks, {})

  zonal_disks_map = {
    for k, v in local.raw_zonal_disks : try(v.name, tostring(k)) => {
      name                       = try(v.name, tostring(k))
      project_id                 = try(v.project_id, local.default_project_id)
      zone                       = try(v.zone, "${local.default_region}-a")
      size                       = try(v.size_gb, try(v.size, 50))
      type                       = try(v.type, "pd-balanced")
      image                      = try(v.image, null)
      snapshot                   = try(v.snapshot, null)
      kms_key_self_link          = try(v.kms_key_self_link, try(v.kms_key_name, null))
      physical_block_size_bytes  = try(v.physical_block_size_bytes, null)
      provisioned_iops           = try(v.provisioned_iops, null)
      provisioned_throughput     = try(v.provisioned_throughput, null)
      snapshot_policy            = try(v.snapshot_policy, null)
      labels                     = try(v.labels, {})
    }
  }

  zonal_disk_attachments = {
    for k, v in local.zonal_disks_map : k => v
    if v.snapshot_policy != null
  }

  # ----------------------------------------------------------------------------
  # 5. Compute Disks: Regional Disks (HA Synchronous Replication)
  # ----------------------------------------------------------------------------
  raw_regional_disks = try(local.raw_compute_disks.regional_disks, {})

  regional_disks_map = {
    for k, v in local.raw_regional_disks : try(v.name, tostring(k)) => {
      name                      = try(v.name, tostring(k))
      project_id                = try(v.project_id, local.default_project_id)
      region                    = try(v.region, local.default_region)
      replica_zones             = try(v.replica_zones, ["${try(v.region, local.default_region)}-a", "${try(v.region, local.default_region)}-b"])
      size                      = try(v.size_gb, try(v.size, 100))
      type                      = try(v.type, "pd-balanced")
      kms_key_self_link         = try(v.kms_key_self_link, try(v.kms_key_name, null))
      physical_block_size_bytes = try(v.physical_block_size_bytes, null)
      snapshot_policy           = try(v.snapshot_policy, null)
      labels                    = try(v.labels, {})
    }
  }

  regional_disk_attachments = {
    for k, v in local.regional_disks_map : k => v
    if v.snapshot_policy != null
  }

  # ----------------------------------------------------------------------------
  # 6. Filestore (NFS Instances)
  # ----------------------------------------------------------------------------
  raw_filestore = try(local.cfg.filestore, {})
  raw_instances = try(local.raw_filestore.instances, local.raw_filestore)

  filestore_instances_map = {
    for k, v in local.raw_instances : try(v.name, tostring(k)) => {
      name               = try(v.name, tostring(k))
      project_id         = try(v.project_id, local.default_project_id)
      location           = try(v.zone, try(v.location, "${local.default_region}-a"))
      tier               = upper(try(v.tier, "BASIC_HDD"))
      description        = try(v.description, "Filestore NFS instance managed by Terraform")
      kms_key_name       = try(v.kms_key_name, null)
      labels             = try(v.labels, {})
      file_share_name    = try(v.file_shares.name, "vol1")
      capacity_gb        = try(v.file_shares.capacity_gb, 1024)
      source_backup      = try(v.file_shares.source_backup, null)
      nfs_export_options = try(v.file_shares.nfs_export_options, [])
      network            = try(v.network.name, try(v.network, "default"))
      network_modes      = try(v.network.modes, ["MODE_IPV4"])
      reserved_ip_range  = try(v.network.reserved_ip_range, null)
      connect_mode       = upper(try(v.network.connect_mode, "DIRECT_PEERING"))
    } if can(v.tier) || can(v.file_shares) || can(v.network)
  }
}
