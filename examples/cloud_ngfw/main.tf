module "iam_service_account" {
  source = "../../modules/iam_service_account"

  for_each = var.service_accounts

  service_account_id = "${var.name_prefix}${each.value.service_account_id}"
  display_name       = "${var.name_prefix}${each.value.display_name}"
  roles              = each.value.roles
  project_id         = var.project
}

module "vpc" {
  source = "../../modules/vpc"

  for_each = var.networks

  project_id                      = var.project
  name                            = "${var.name_prefix}${each.value.vpc_name}"
  create_network                  = each.value.create_network
  delete_default_routes_on_create = each.value.delete_default_routes_on_create
  mtu                             = each.value.mtu
  routing_mode                    = each.value.routing_mode
  subnetworks = { for k, v in each.value.subnetworks : k => merge(v, {
    name = "${var.name_prefix}${v.name}"
    })
  }
  firewall_rules = try({ for k, v in each.value.firewall_rules : k => merge(v, {
    name = "${var.name_prefix}${v.name}"
    })
  }, {})
}

module "cloud_nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "5.3.0"

  for_each = var.cloud_nats

  name                               = "${var.name_prefix}${each.value.name}"
  project_id                         = var.project
  region                             = each.value.region
  create_router                      = true
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  network                            = module.vpc[each.value.vpc_network_key].network.self_link
  min_ports_per_vm                   = each.value.min_ports_per_vm
  max_ports_per_vm                   = each.value.max_ports_per_vm
  enable_dynamic_port_allocation     = each.value.enable_dynamic_port_allocation
  log_config_enable                  = each.value.log_config_enable
  subnetworks = [for v in each.value.subnetworks : {
    name                     = module.vpc[each.value.vpc_network_key].subnetworks[v.subnetwork_key].name
    source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
    secondary_ip_range_names = []
  }]
  router = "${var.name_prefix}${each.value.router_name}"
}

data "google_compute_image" "my_image" {
  family  = "ubuntu-pro-2204-lts"
  project = "ubuntu-os-pro-cloud"
}

resource "google_compute_instance" "linux_vm" {
  for_each = var.linux_vms

  name         = "${var.name_prefix}${each.key}"
  machine_type = each.value.linux_machine_type
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.my_image.id
      size  = each.value.linux_disk_size
    }
  }

  network_interface {
    subnetwork = module.vpc[each.value.vpc_network_key].subnetworks[each.value.subnetwork_key].self_link
    network_ip = each.value.private_ip
  }

  metadata_startup_script = each.value.metadata_startup_script
  metadata = {
    enable-oslogin = true
  }

  service_account {
    email  = module.iam_service_account[each.value.service_account_key].email
    scopes = each.value.scopes
  }

}

module "ngfw" {
  source = "../../modules/cloud_ngfw"

  name_prefix = var.name_prefix
  firewall_endpoints = { for k, v in var.firewall_endpoints :
    k => merge(v, {
      network_id         = module.vpc[v.vpc_network_key].network.id
      project_id         = var.project
      billing_project_id = var.project
      org_id             = var.org_id
    })
  }
  network_security_profiles = { for k, v in var.network_security_profiles :
    k => merge(v, {
      org_id = var.org_id
    })
  }

  network_policies = merge(
    var.network_policies,
    {
      project_id = var.project,
      network_associations = { for kk, vv in var.network_policies.network_associations :
        kk => merge(vv, {
          network_id = module.vpc[vv.vpc_network_key].network.id
        })
      }
    }
  )
}
