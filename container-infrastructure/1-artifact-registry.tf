/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# ------------------------------------------------------------------------------
# 1. Artifact Registry Repositories (OCI & Docker Container Storage)
# ------------------------------------------------------------------------------
resource "google_artifact_registry_repository" "registries" {
  for_each = local.artifact_registries

  project       = each.value.project_id
  location      = each.value.location
  repository_id = each.value.name
  format        = each.value.format
  description   = each.value.description
  mode          = each.value.mode
  labels        = each.value.labels

  # Immutable Tags Protection (Enforces strict git SHA / semver immutability)
  dynamic "docker_config" {
    for_each = each.value.format == "DOCKER" ? [1] : []
    content {
      immutable_tags = each.value.immutable_tags
    }
  }

  # Automated Cleanup Policies (Prune untagged, retain last N versions)
  dynamic "cleanup_policies" {
    for_each = each.value.cleanup_policies
    content {
      id     = cleanup_policies.key
      action = upper(try(cleanup_policies.value.action, "DELETE"))

      dynamic "condition" {
        for_each = try(cleanup_policies.value.most_recent_versions, null) == null && try(cleanup_policies.value.condition, null) != null ? [cleanup_policies.value.condition] : []
        content {
          tag_state             = try(condition.value.tag_state, null)
          tag_prefixes          = try(condition.value.tag_prefixes, null)
          version_name_prefixes = try(condition.value.version_name_prefixes, null)
          package_name_prefixes = try(condition.value.package_name_prefixes, null)
          older_than            = try(condition.value.older_than, null)
          newer_than            = try(condition.value.newer_than, null)
        }
      }

      dynamic "most_recent_versions" {
        for_each = try(cleanup_policies.value.most_recent_versions, null) != null ? [cleanup_policies.value.most_recent_versions] : []
        content {
          package_name_prefixes = try(most_recent_versions.value.package_name_prefixes, null)
          keep_count            = try(most_recent_versions.value.keep_count, 10)
        }
      }
    }
  }
}
