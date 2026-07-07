locals {
  security_profile_group_id = var.create_security_profile ? google_network_security_security_profile_group.this[0].id : var.existing_security_profile_group_id

  firewall_policy_rule_pairs = {
    for pair in flatten([
      for vpc_key, vpc in var.consumer_vpcs : [
        for idx, rule in coalesce(vpc.firewall_policy_rules, var.firewall_policy_rules) : {
          key     = "${vpc_key}--${idx}"
          vpc_key = vpc_key
          rule    = rule
        }
      ]
    ]) : pair.key => pair
  }
}


resource "google_network_security_intercept_deployment_group" "this" {
  intercept_deployment_group_id = "${var.name_prefix}intercept-dgrp"
  location                      = "global"
  network                       = var.producer_vpc_self_link

  lifecycle {
    precondition {
      condition     = var.create_security_profile || var.existing_security_profile_group_id != null
      error_message = "existing_security_profile_group_id must be set when create_security_profile = false."
    }
  }
}

resource "google_network_security_intercept_deployment" "this" {
  for_each = var.zonal_forwarding_rules

  intercept_deployment_id    = "${var.name_prefix}intercept-${replace(each.key, "/", "-")}"
  location                   = each.key
  forwarding_rule            = each.value
  intercept_deployment_group = google_network_security_intercept_deployment_group.this.id
}

resource "google_network_security_intercept_endpoint_group" "this" {
  intercept_endpoint_group_id = "${var.name_prefix}intercept-egrp"
  location                    = "global"
  intercept_deployment_group  = google_network_security_intercept_deployment_group.this.id
}


resource "google_network_security_security_profile" "this" {
  count = var.create_security_profile ? 1 : 0

  name     = "${var.name_prefix}intercept-prof"
  parent   = "projects/${var.project_id}"
  location = "global"
  type     = "CUSTOM_INTERCEPT"

  custom_intercept_profile {
    intercept_endpoint_group = google_network_security_intercept_endpoint_group.this.id
  }
}

resource "google_network_security_security_profile_group" "this" {
  count = var.create_security_profile ? 1 : 0

  name                     = "${var.name_prefix}intercept-pgrp"
  parent                   = "projects/${var.project_id}"
  location                 = "global"
  custom_intercept_profile = google_network_security_security_profile.this[0].id
}


resource "google_network_security_intercept_endpoint_group_association" "this" {
  for_each = var.consumer_vpcs

  # GCP requires the association to be in the same project as the consumer VPC network.
  project = coalesce(each.value.project_id, var.project_id)

  intercept_endpoint_group_association_id = "${var.name_prefix}assoc-${each.key}"
  location                                = "global"
  intercept_endpoint_group                = google_network_security_intercept_endpoint_group.this.id
  network                                 = each.value.self_link

  timeouts {
    create = "30m"
    delete = "30m"
  }
}

resource "google_compute_network_firewall_policy" "this" {
  for_each    = var.consumer_vpcs
  name        = "${var.name_prefix}fwpol-${each.key}"
  project     = coalesce(each.value.project_id, var.project_id)
  description = "NSI intercept policy for ${each.key}"
}

resource "google_compute_network_firewall_policy_rule" "this" {
  for_each        = local.firewall_policy_rule_pairs
  firewall_policy = google_compute_network_firewall_policy.this[each.value.vpc_key].name
  project         = coalesce(var.consumer_vpcs[each.value.vpc_key].project_id, var.project_id)
  priority        = each.value.rule.priority
  direction       = each.value.rule.direction
  action          = "apply_security_profile_group"
  description     = each.value.rule.description

  security_profile_group = local.security_profile_group_id

  match {
    src_ip_ranges  = each.value.rule.match.src_ip_ranges
    dest_ip_ranges = each.value.rule.match.dest_ip_ranges

    dynamic "layer4_configs" {
      for_each = each.value.rule.match.layer4_configs
      content {
        ip_protocol = layer4_configs.value.ip_protocol
        ports       = layer4_configs.value.ports
      }
    }
  }
}

resource "google_compute_network_firewall_policy_association" "this" {
  for_each          = var.consumer_vpcs
  name              = "${var.name_prefix}fwpol-assoc-${each.key}"
  project           = coalesce(each.value.project_id, var.project_id)
  attachment_target = each.value.self_link
  firewall_policy   = google_compute_network_firewall_policy.this[each.key].id
}
