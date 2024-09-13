locals {
  local_network_name = reverse(split("/", var.local_network))[0]
  peer_network_name  = reverse(split("/", var.peer_network))[0]
}

resource "google_compute_network_peering" "local" {
  name         = coalesce(var.local_peering_name, "${var.name_prefix}${local.local_network_name}-${local.peer_network_name}")
  network      = var.local_network
  peer_network = var.peer_network

  export_custom_routes = var.local_export_custom_routes
  import_custom_routes = var.local_import_custom_routes

  export_subnet_routes_with_public_ip = var.local_export_subnet_routes_with_public_ip
  import_subnet_routes_with_public_ip = var.local_import_subnet_routes_with_public_ip
  stack_type                          = var.stack_type
}

resource "google_compute_network_peering" "peer" {
  name         = coalesce(var.peer_peering_name, "${var.name_prefix}${local.peer_network_name}-${local.local_network_name}")
  network      = var.peer_network
  peer_network = var.local_network

  export_custom_routes = var.peer_export_custom_routes
  import_custom_routes = var.peer_import_custom_routes

  export_subnet_routes_with_public_ip = var.peer_export_subnet_routes_with_public_ip
  import_subnet_routes_with_public_ip = var.peer_import_subnet_routes_with_public_ip
  stack_type                          = var.stack_type
}