# ==============================================================================
# 10. Organization Governance: Essential Contacts & Resource Tag Hierarchy
# ==============================================================================
# Provisions organization-wide governance primitives:
# 1. Essential Contacts: Configures verified incident, security, and billing
#    notification recipients for Google Cloud operational communications.
# 2. Resource Tag Keys & Values: Centralizes cryptographic tag taxonomies at the
#    organization level for policy enforcement, ABAC, and compliance.
# ==============================================================================

# ------------------------------------------------------------------------------
# 10.1 Essential Contacts (Security, Technical, and Billing Notifications)
# ------------------------------------------------------------------------------
resource "google_essential_contacts_contact" "contacts" {
  for_each = { for c in lookup(local.config, "essential_contacts", []) : c.email => c }

  parent                              = "organizations/${local.config.organization_id}"
  email                               = each.value.email
  notification_category_subscriptions = each.value.notification_categories
  language_tag                        = lookup(each.value, "language_tag", "en-US")
}

# ------------------------------------------------------------------------------
# 10.2 Resource Tag Keys (Organization Level)
# ------------------------------------------------------------------------------
resource "google_tags_tag_key" "keys" {
  for_each = { for t in lookup(local.config, "tags", []) : t.key => t }

  parent      = "organizations/${local.config.organization_id}"
  short_name  = each.value.key
  description = lookup(each.value, "description", null)
}

# ------------------------------------------------------------------------------
# 10.3 Resource Tag Values
# ------------------------------------------------------------------------------
resource "google_tags_tag_value" "values" {
  for_each = { for tv in local.tag_values_flat : tv.key => tv }

  parent      = google_tags_tag_key.keys[each.value.tag_key].id
  short_name  = each.value.value
  description = "Tag value ${each.value.value} for key ${each.value.tag_key}"
}
