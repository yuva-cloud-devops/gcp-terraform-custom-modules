# ==============================================================================
# Cloud Storage (GCS) Buckets, Lifecycle Rules, Retention & IAM
# ==============================================================================

resource "google_storage_bucket" "buckets" {
  for_each = local.buckets_map

  name                        = each.value.name
  project                     = each.value.project_id
  location                    = each.value.location
  storage_class               = each.value.storage_class
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  public_access_prevention    = each.value.public_access_prevention
  force_destroy               = each.value.force_destroy
  labels                      = each.value.labels

  versioning {
    enabled = each.value.versioning
  }

  dynamic "autoclass" {
    for_each = each.value.autoclass != null ? [each.value.autoclass] : []
    content {
      enabled                = try(autoclass.value.enabled, true)
      terminal_storage_class = try(autoclass.value.terminal_storage_class, null)
    }
  }

  dynamic "encryption" {
    for_each = each.value.kms_key_name != null ? [1] : []
    content {
      default_kms_key_name = each.value.kms_key_name
    }
  }

  dynamic "retention_policy" {
    for_each = each.value.retention_policy != null ? [each.value.retention_policy] : []
    content {
      retention_period = retention_policy.value.retention_period
      is_locked        = retention_policy.value.is_locked
    }
  }

  dynamic "soft_delete_policy" {
    for_each = each.value.soft_delete_policy != null ? [each.value.soft_delete_policy] : []
    content {
      retention_duration_seconds = soft_delete_policy.value.retention_duration_seconds
    }
  }

  dynamic "cors" {
    for_each = each.value.cors
    content {
      origin          = try(cors.value.origin, ["*"])
      method          = try(cors.value.method, ["GET", "HEAD", "PUT", "POST"])
      response_header = try(cors.value.response_header, ["*"])
      max_age_seconds = try(cors.value.max_age_seconds, 3600)
    }
  }

  dynamic "website" {
    for_each = each.value.website != null ? [each.value.website] : []
    content {
      main_page_suffix = try(website.value.main_page_suffix, "index.html")
      not_found_page   = try(website.value.not_found_page, "404.html")
    }
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }
      condition {
        age                        = try(lifecycle_rule.value.condition.age, null)
        created_before             = try(lifecycle_rule.value.condition.created_before, null)
        with_state                 = try(lifecycle_rule.value.condition.with_state, null)
        matches_storage_class      = try(lifecycle_rule.value.condition.matches_storage_class, null)
        matches_prefix             = try(lifecycle_rule.value.condition.matches_prefix, null)
        matches_suffix             = try(lifecycle_rule.value.condition.matches_suffix, null)
        num_newer_versions         = try(lifecycle_rule.value.condition.num_newer_versions, null)
        custom_time_before         = try(lifecycle_rule.value.condition.custom_time_before, null)
        days_since_custom_time     = try(lifecycle_rule.value.condition.days_since_custom_time, null)
        days_since_noncurrent_time = try(lifecycle_rule.value.condition.days_since_noncurrent_time, null)
        noncurrent_time_before     = try(lifecycle_rule.value.condition.noncurrent_time_before, null)
      }
    }
  }
}

resource "google_storage_bucket_iam_member" "members" {
  for_each = local.bucket_iam_members_map

  bucket = try(google_storage_bucket.buckets[each.value.bucket].name, each.value.bucket)
  role   = each.value.role
  member = each.value.member
}
