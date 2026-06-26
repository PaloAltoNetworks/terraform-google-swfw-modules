locals {
  hub_name = coalesce(var.hub_name, "${var.name_prefix}ncc-hub")
  hub_id   = var.create_hub ? google_network_connectivity_hub.this[0].id : var.existing_hub_id
}

resource "google_network_connectivity_hub" "this" {
  count   = var.create_hub ? 1 : 0
  name    = local.hub_name
  project = var.project_id

  # policy_mode = "PRESET" is required for preset_topology to be accepted.
  policy_mode     = "PRESET"
  preset_topology = var.topology
}

resource "google_network_connectivity_spoke" "this" {
  for_each = var.vpc_spokes

  name     = "${var.name_prefix}spoke-${each.key}"
  location = "global"
  project  = var.project_id
  hub      = local.hub_id

  linked_vpc_network {
    uri                   = each.value.vpc_self_link
    exclude_export_ranges = each.value.exclude_export_ranges
  }

  lifecycle {
    precondition {
      condition     = var.create_hub || var.existing_hub_id != null
      error_message = "existing_hub_id must be set when create_hub = false."
    }
  }
}
