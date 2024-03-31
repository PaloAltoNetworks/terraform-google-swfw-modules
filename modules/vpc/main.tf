locals {
  subnetworks_existing = {
    for k, v in var.subnetworks
    : k => v
    if try(v.create_subnetwork == false, false)
  }

  // Some subnetworks need to be created:
  subnetworks_to_create = {
    for k, v in var.subnetworks
    : k => v
    if !(try(v.create_subnetwork == false, false))
  }
}

data "google_compute_network" "this" {
  count = var.create_network == true ? 0 : 1

  name    = var.name
  project = var.project_id
}

resource "google_compute_network" "this" {
  count = var.create_network == true ? 1 : 0

  name                            = var.name
  project                         = var.project_id
  delete_default_routes_on_create = var.delete_default_routes_on_create
  mtu                             = var.mtu
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
}

data "google_compute_subnetwork" "this" {
  for_each = local.subnetworks_existing

  name    = each.value.name
  project = var.project_id
  region  = each.value.region
}

resource "google_compute_subnetwork" "this" {
  for_each = local.subnetworks_to_create

  name             = each.value.name
  ip_cidr_range    = each.value.ip_cidr_range
  network          = try(data.google_compute_network.this[0].self_link, google_compute_network.this[0].self_link)
  region           = each.value.region
  project          = var.project_id
  stack_type       = each.value.stack_type
  ipv6_access_type = each.value.stack_type == "IPV4_IPV6" ? "EXTERNAL" : ""
}

resource "google_compute_firewall" "this" {
  for_each = var.firewall_rules

  name                    = "${each.value.name}-ingress"
  network                 = try(data.google_compute_network.this[0].self_link, google_compute_network.this[0].self_link)
  direction               = "INGRESS"
  source_ranges           = each.value.source_ranges
  source_tags             = each.value.source_tags
  source_service_accounts = each.value.source_service_accounts
  project                 = var.project_id
  priority                = each.value.priority
  target_service_accounts = each.value.target_service_accounts
  target_tags             = each.value.target_tags


  allow {
    protocol = each.value.allowed_protocol
    ports    = each.value.allowed_ports
  }

  dynamic "log_config" {
    for_each = compact(try([each.value.log_metadata], []))

    content {
      metadata = log_config.value
    }
  }
}