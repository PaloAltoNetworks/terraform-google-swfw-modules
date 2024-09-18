locals {
  create_public_ip = {
    for k, v in var.network_interfaces : k => try(v.create_public_ip, false)
  }
  access_configs = {
    for k, v in var.network_interfaces : k => {
      nat_ip                 = try(v.public_ip, google_compute_address.public[k].address, null)
      public_ptr_domain_name = try(v.public_ptr_domain_name, google_compute_address.public[k].public_ptr_domain_name, null)
    }
    if try(v.public_ip, null) != null || local.create_public_ip[k]
  }
  create_public_ipv6 = {
    for k, v in var.network_interfaces : k => try(v.create_public_ipv6, false)
  }
  ipv6_access_configs = {
    for k, v in var.network_interfaces : k => {
      external_ipv6               = try(split("/", v.public_ipv6)[0], google_compute_address.public_ipv6[k].address, null)
      external_ipv6_prefix_length = try(split("/", v.public_ipv6)[1], google_compute_address.public_ipv6[k].prefix_length, null)
      public_ptr_domain_name      = try(v.public_ipv6_ptr_domain_name, null)
    }
    if try(v.public_ipv6, null) != null || local.create_public_ipv6[k]
  }
}

data "google_compute_image" "vmseries" {
  count = var.custom_image == null ? 1 : 0

  name    = var.vmseries_image
  project = "paloaltonetworksgcp-public"
}

data "google_compute_subnetwork" "this" {
  for_each  = { for k, v in var.network_interfaces : k => v }
  project   = var.project
  self_link = each.value.subnetwork
}

resource "null_resource" "dependency_getter" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}

resource "google_compute_address" "private" {
  for_each = { for k, v in var.network_interfaces : k => v }

  name         = try(each.value.private_ip_name, "${var.name}-${each.key}-private")
  address_type = "INTERNAL"
  address      = try(each.value.private_ip, null)
  project      = var.project
  subnetwork   = each.value.subnetwork
  region       = data.google_compute_subnetwork.this[each.key].region
}

resource "google_compute_address" "private_ipv6" {
  for_each = { for k, v in var.network_interfaces :
    k => v if try(v.stack_type, "IPV4_ONLY") == "IPV4_IPV6"
    && try(v.create_private_ipv6, true) == true
    && local.create_public_ipv6[k] == false
  }

  name         = try(each.value.private_ipv6_name, "${var.name}-${each.key}-private-ipv6")
  address_type = "INTERNAL"
  ip_version   = "IPV6"
  project      = var.project
  subnetwork   = each.value.subnetwork
  region       = data.google_compute_subnetwork.this[each.key].region
}

resource "google_compute_address" "public" {
  for_each = { for k, v in var.network_interfaces : k => v if local.create_public_ip[k] && try(v.public_ip, null) == null }

  name         = try(each.value.public_ip_name, "${var.name}-${each.key}-public")
  address_type = "EXTERNAL"
  project      = var.project
  region       = data.google_compute_subnetwork.this[each.key].region
}

resource "google_compute_address" "public_ipv6" {
  for_each = { for k, v in var.network_interfaces : k => v if local.create_public_ipv6[k] && try(v.public_ipv6, null) == null }

  name               = try(each.value.public_ipv6_name, "${var.name}-${each.key}-public-ipv6")
  address_type       = "EXTERNAL"
  ip_version         = "IPV6"
  ipv6_endpoint_type = "VM"
  subnetwork         = each.value.subnetwork
  project            = var.project
  region             = data.google_compute_subnetwork.this[each.key].region
}

resource "google_compute_instance" "this" {

  name                      = var.name
  zone                      = var.zone
  machine_type              = var.machine_type
  min_cpu_platform          = var.min_cpu_platform
  deletion_protection       = var.deletion_protection
  labels                    = var.labels
  tags                      = var.tags
  metadata_startup_script   = var.metadata_startup_script
  project                   = var.project
  resource_policies         = var.resource_policies
  can_ip_forward            = true
  allow_stopping_for_update = true

  metadata = merge({
    serial-port-enable = true
    ssh-keys           = var.ssh_keys
    },
    var.bootstrap_options,
    var.metadata
  )

  service_account {
    email  = var.service_account
    scopes = var.scopes
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces

    content {
      stack_type   = try(network_interface.value.stack_type, "IPV4_ONLY")
      network_ip   = google_compute_address.private[network_interface.key].address
      ipv6_address = try(google_compute_address.private_ipv6[network_interface.key].address, null)
      subnetwork   = network_interface.value.subnetwork

      dynamic "access_config" {
        for_each = try(local.access_configs[network_interface.key] != null, false) ? ["one"] : []
        content {
          nat_ip                 = local.access_configs[network_interface.key].nat_ip
          public_ptr_domain_name = local.access_configs[network_interface.key].public_ptr_domain_name
        }
      }

      dynamic "alias_ip_range" {
        for_each = try(network_interface.value.alias_ip_ranges, [])
        content {
          ip_cidr_range         = alias_ip_range.value.ip_cidr_range
          subnetwork_range_name = try(alias_ip_range.value.subnetwork_range_name, null)
        }
      }

      dynamic "ipv6_access_config" {
        for_each = try(local.ipv6_access_configs[network_interface.key] != null, false) ? ["one"] : []
        content {
          external_ipv6               = try(local.ipv6_access_configs[network_interface.key].external_ipv6, null)
          external_ipv6_prefix_length = try(local.ipv6_access_configs[network_interface.key].external_ipv6_prefix_length, null)
          network_tier                = "PREMIUM"
          public_ptr_domain_name      = try(local.ipv6_access_configs[network_interface.key].public_ptr_domain_name, null)
        }
      }
    }
  }

  boot_disk {
    initialize_params {
      image = coalesce(var.custom_image, try(data.google_compute_image.vmseries[0].self_link, null))
      type  = var.disk_type
    }
  }

  depends_on = [
    null_resource.dependency_getter
  ]
}

# The Deployment Guide Jan 2020 recommends per-zone instance groups (instead of regional IGMs).
resource "google_compute_instance_group" "this" {
  count = var.create_instance_group ? 1 : 0

  name      = "${var.name}-${var.zone}"
  zone      = var.zone
  project   = var.project
  instances = [google_compute_instance.this.self_link]

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }
}

