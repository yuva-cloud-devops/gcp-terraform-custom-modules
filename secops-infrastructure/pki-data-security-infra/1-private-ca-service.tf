# ==============================================================================
# 1. Certificate Authority Service (CAS / Private CA)
# ==============================================================================
# Provisions Private CA Pools (DEVOPS / ENTERPRISE) and Root / Subordinate CAs
# with automated lifecycle management, hardware-backed keys, and issuance policies.
# ==============================================================================

# ------------------------------------------------------------------------------
# Private CA Pools
# ------------------------------------------------------------------------------
resource "google_privateca_ca_pool" "pools" {
  for_each = local.ca_pools_map

  name     = each.value.name
  location = each.value.location
  project  = each.value.project_id
  tier     = each.value.tier

  publishing_options {
    publish_ca_cert = each.value.publish_ca_cert
    publish_crl     = each.value.publish_crl
  }

  dynamic "issuance_policy" {
    for_each = each.value.issuance_policy != null ? [each.value.issuance_policy] : []
    content {
      maximum_lifetime = try(issuance_policy.value.maximum_lifetime, null)

      dynamic "allowed_key_types" {
        for_each = try(issuance_policy.value.allowed_key_types, [])
        content {
          dynamic "elliptic_curve" {
            for_each = try(allowed_key_types.value.elliptic_curve, null) != null ? [allowed_key_types.value.elliptic_curve] : []
            content {
              signature_algorithm = elliptic_curve.value
            }
          }
          dynamic "rsa" {
            for_each = try(allowed_key_types.value.rsa, null) != null ? [allowed_key_types.value.rsa] : []
            content {
              min_modulus_size = try(rsa.value.min_modulus_size, rsa.value)
              max_modulus_size = try(rsa.value.max_modulus_size, null)
            }
          }
        }
      }
    }
  }

  labels = each.value.labels
}

# ------------------------------------------------------------------------------
# Certificate Authorities (Root & Subordinate CAs)
# ------------------------------------------------------------------------------
resource "google_privateca_certificate_authority" "authorities" {
  for_each = local.certificate_authorities_map

  certificate_authority_id = each.value.ca_id
  pool                     = try(google_privateca_ca_pool.pools[each.value.pool_name].name, each.value.pool_name)
  location                 = each.value.location
  project                  = each.value.project_id
  type                     = each.value.type
  lifetime                 = each.value.lifetime

  config {
    subject_config {
      subject {
        common_name         = each.value.common_name
        organization        = each.value.organization
        country_code        = each.value.country_code
        organizational_unit = each.value.org_unit
        locality            = each.value.locality
        province            = each.value.province
      }

      dynamic "subject_alt_name" {
        for_each = length(each.value.dns_names) > 0 ? [1] : []
        content {
          dns_names = each.value.dns_names
        }
      }
    }

    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth = true
          client_auth = true
        }
      }
    }
  }

  key_spec {
    algorithm = each.value.algorithm
  }

  deletion_protection                    = each.value.deletion_protection
  skip_grace_period                      = each.value.skip_grace_period
  ignore_active_certificates_on_deletion = each.value.ignore_active_certificates_on_deletion

  labels = each.value.labels

  depends_on = [
    google_privateca_ca_pool.pools
  ]
}
