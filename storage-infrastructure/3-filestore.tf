# ==============================================================================
# Google Cloud Filestore (Managed NFS File Shares)
# ==============================================================================

resource "google_filestore_instance" "instances" {
  for_each = local.filestore_instances_map

  name         = each.value.name
  project      = each.value.project_id
  location     = each.value.location
  tier         = each.value.tier
  description  = each.value.description
  labels       = each.value.labels
  kms_key_name = each.value.kms_key_name

  file_shares {
    name          = each.value.file_share_name
    capacity_gb   = each.value.capacity_gb
    source_backup = each.value.source_backup

    dynamic "nfs_export_options" {
      for_each = each.value.nfs_export_options
      content {
        ip_ranges   = try(nfs_export_options.value.ip_ranges, ["0.0.0.0/0"])
        access_mode = try(nfs_export_options.value.access_mode, "READ_WRITE")
        squash_mode = try(nfs_export_options.value.squash_mode, "NO_ROOT_SQUASH")
        anon_uid    = try(nfs_export_options.value.anon_uid, null)
        anon_gid    = try(nfs_export_options.value.anon_gid, null)
      }
    }
  }

  networks {
    network           = each.value.network
    modes             = each.value.network_modes
    reserved_ip_range = each.value.reserved_ip_range
    connect_mode      = each.value.connect_mode
  }
}
