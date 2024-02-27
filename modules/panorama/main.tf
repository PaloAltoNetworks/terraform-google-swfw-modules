data "google_compute_image" "this" {
  count = var.custom_image != null ? 0 : 1

  project = "paloaltonetworksgcp-public"
  name    = var.panorama_version
}

# Permanent private address, not ephemeral, because the managed firewalls keep it saved.
resource "google_compute_address" "private" {
  name         = "${var.name}-private"
  project      = var.project
  region       = var.region
  subnetwork   = var.subnet
  address      = try(var.private_static_ip, null)
  address_type = "INTERNAL"
}

# Permanent public address, not ephemeral.
resource "google_compute_address" "public" {
  count = var.attach_public_ip && var.public_static_ip == null ? 1 : 0

  name    = "${var.name}-public"
  project = var.project
  region  = var.region
  address = try(var.public_static_ip, null)
}

resource "google_compute_disk" "this" {
  for_each = { for k, v in var.log_disks : k => v }

  name    = each.value.name
  project = var.project
  zone    = var.zone
  type    = each.value.type
  size    = each.value.size
}

resource "google_compute_instance" "this" {
  name                      = var.name
  zone                      = var.zone
  machine_type              = var.machine_type
  min_cpu_platform          = var.min_cpu_platform
  deletion_protection       = var.deletion_protection
  labels                    = var.labels
  tags                      = var.tags
  project                   = var.project
  can_ip_forward            = false
  allow_stopping_for_update = true

  metadata = merge({
    serial-port-enable = true
    ssh-keys           = var.ssh_keys
  }, var.metadata)

  service_account {
    email  = var.service_account
    scopes = var.scopes
  }

  network_interface {

    dynamic "access_config" {
      for_each = var.attach_public_ip ? [""] : []
      content {
        nat_ip = var.reserve_public_ip ? google_compute_address.public[0].address : var.public_static_ip
      }
    }

    network_ip = google_compute_address.private.address
    subnetwork = var.subnet
  }

  boot_disk {
    initialize_params {
      image = coalesce(var.custom_image, try(data.google_compute_image.this[0].id, null))
      size  = var.disk_size
      type  = var.disk_type
    }
  }

  dynamic "attached_disk" {
    for_each = google_compute_disk.this
    content {
      source = google_compute_disk.this[attached_disk.key].id
    }
  }
}
