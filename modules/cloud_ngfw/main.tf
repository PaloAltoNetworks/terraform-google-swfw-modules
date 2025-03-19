# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_security_firewall_endpoint
resource "google_network_security_firewall_endpoint" "this" {

  for_each = var.firewall_endpoints

  name               = "${var.name_prefix}${each.value.firewall_endpoint_name}"
  parent             = "organizations/${each.value.org_id}"
  location           = each.value.zone
  billing_project_id = each.value.billing_project_id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_security_firewall_endpoint_association
resource "google_network_security_firewall_endpoint_association" "this" {

  for_each = var.firewall_endpoints

  name                  = "${var.name_prefix}${each.value.firewall_endpoint_association_name}"
  parent                = "projects/${each.value.project_id}"
  location              = each.value.zone
  network               = each.value.network_id
  firewall_endpoint     = google_network_security_firewall_endpoint.this[each.key].id
  tls_inspection_policy = each.value.tls_inspection_policy != null ? each.value.tls_inspection_policy : null
  labels                = each.value.labels
  disabled              = each.value.disabled
}

#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_security_security_profile
resource "google_network_security_security_profile" "this" {

  for_each = var.network_security_profiles

  name        = "${var.name_prefix}${each.value.profile_name}"
  parent      = "organizations/${each.value.org_id}"
  description = each.value.profile_description
  labels      = each.value.labels
  location    = each.value.location
  type        = "THREAT_PREVENTION"

  threat_prevention_profile {
    dynamic "severity_overrides" {
      for_each = each.value.severity_overrides
      content {
        severity = severity_overrides.key
        action   = severity_overrides.value
      }
    }
    dynamic "threat_overrides" {
      for_each = each.value.threat_overrides
      content {
        action    = threat_overrides.value
        threat_id = threat_overrides.key
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_security_security_profile_group
resource "google_network_security_security_profile_group" "this" {

  for_each = var.network_security_profiles

  name                      = "${var.name_prefix}${each.value.profile_group_name}"
  parent                    = "organizations/${each.value.org_id}"
  description               = each.value.profile_group_description
  labels                    = each.value.labels
  location                  = each.value.location
  threat_prevention_profile = google_network_security_security_profile.this[each.key].id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_firewall_policy
resource "google_compute_network_firewall_policy" "this" {

  count = var.network_policies.create_firewall_policy ? 1 : 0

  name        = "${var.name_prefix}${var.network_policies.policy_name}"
  description = var.network_policies.description
  project     = var.network_policies.project_id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_firewall_policy_rule
resource "google_compute_network_firewall_policy_rule" "this" {

  for_each = var.network_policies.rules

  rule_name               = "${var.name_prefix}${each.value.rule_name}"
  description             = each.value.description
  direction               = each.value.direction
  enable_logging          = each.value.enable_logging
  tls_inspect             = each.value.tls_inspect
  firewall_policy         = try(google_compute_network_firewall_policy.this[0].name, var.network_policies.policy_name)
  priority                = each.value.priority
  action                  = each.value.action
  security_profile_group  = each.value.action == "apply_security_profile_group" ? try("${"//networksecurity.googleapis.com/"}${google_network_security_security_profile_group.this[each.value.security_group_key].id}", "${"//networksecurity.googleapis.com/"}${each.value.security_group_id}") : null
  target_service_accounts = each.value.target_service_accounts
  disabled                = each.value.disabled
  dynamic "target_secure_tags" {
    for_each = each.value.target_secure_tags
    content {
      name = target_secure_tags.name
    }
  }
  match {
    src_ip_ranges             = each.value.src_ip_ranges
    dest_ip_ranges            = each.value.dest_ip_ranges
    src_address_groups        = each.value.src_address_groups
    dest_address_groups       = each.value.dest_address_groups
    src_fqdns                 = each.value.src_fqdns
    dest_fqdns                = each.value.dest_fqdns
    src_region_codes          = each.value.src_region_codes
    dest_region_codes         = each.value.dest_region_codes
    src_threat_intelligences  = each.value.src_threat_intelligences
    dest_threat_intelligences = each.value.dest_threat_intelligences

    layer4_configs {
      ip_protocol = each.value.ip_protocol
      ports       = each.value.ports
    }

    dynamic "src_secure_tags" {
      for_each = each.value.src_secure_tags
      content {
        name = src_secure_tags.name
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_firewall_policy_association
resource "google_compute_network_firewall_policy_association" "this" {

  for_each = var.network_policies.network_associations

  name              = "${var.name_prefix}${each.value.policy_association_name}"
  attachment_target = each.value.network_id
  firewall_policy   = google_compute_network_firewall_policy.this[0].name
  project           = var.network_policies.project_id
}
