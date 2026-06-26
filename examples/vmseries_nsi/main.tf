
module "iam_service_account" {
  source = "../../modules/iam_service_account"

  service_account_id = var.service_account.service_account_id
  display_name       = "VM-Series NSI Service Account"
  project_id         = var.project
  roles              = var.service_account.roles
}


module "mgmt_vpc" {
  source = "../../modules/vpc"

  project_id = var.project
  name       = var.mgmt_vpc.name
  subnetworks = {
    mgmt = {
      name          = var.mgmt_vpc.subnetwork_name
      ip_cidr_range = var.mgmt_vpc.ip_cidr_range
      region        = var.region
    }
  }
  firewall_rules = var.mgmt_vpc.firewall_rules
}

module "data_vpc" {
  source = "../../modules/vpc"

  project_id = var.project
  name       = var.data_vpc.name
  subnetworks = {
    data = {
      name          = var.data_vpc.subnetwork_name
      ip_cidr_range = var.data_vpc.ip_cidr_range
      region        = var.region
    }
  }
  firewall_rules = var.data_vpc.firewall_rules
}


module "consumer_vpcs" {
  for_each = var.consumer_vpcs
  source   = "../../modules/vpc"

  project_id = var.project
  name       = each.value.name
  subnetworks = {
    default = {
      name          = each.value.subnetwork_name
      ip_cidr_range = each.value.ip_cidr_range
      region        = var.region
    }
  }
  firewall_rules = each.value.firewall_rules
}


module "vmseries" {
  for_each = var.vmseries
  source   = "../../modules/vmseries"

  name                  = "${var.name_prefix}${each.key}"
  zone                  = each.value.zone
  project               = var.project
  ssh_keys              = var.ssh_keys
  vmseries_image        = var.vmseries_image
  machine_type          = var.vmseries_common.machine_type
  min_cpu_platform      = var.vmseries_common.min_cpu_platform
  service_account       = module.iam_service_account.email
  create_instance_group = true

  bootstrap_options = merge(
    var.vmseries_common.bootstrap_options,
    each.value.bootstrap_options,
    { plugin-op-commands = "geneve-inspect:enable" }
  )

  network_interfaces = [
    {
      subnetwork       = module.mgmt_vpc.subnetworks["mgmt"].self_link
      create_public_ip = var.create_mgmt_public_ip
    },
    {
      subnetwork       = module.data_vpc.subnetworks["data"].self_link
      create_public_ip = false
    },
  ]
}

resource "google_compute_region_health_check" "geneve_hc" {
  name    = "${var.name_prefix}geneve-hc"
  project = var.project
  region  = var.region

  https_health_check {
    port         = 443
    request_path = "/unauth/php/health.php"
  }
}

#
module "geneve_ilb" {
  for_each = var.vmseries
  source   = "../../modules/lb_internal"

  name    = "${var.name_prefix}geneve-ilb-${each.key}"
  project = var.project
  region  = var.region

  subnetwork   = module.data_vpc.subnetworks["data"].self_link
  network      = module.data_vpc.network.self_link
  protocol     = "UDP"
  ip_protocol  = "UDP"
  ports        = ["6081"]
  health_check = google_compute_region_health_check.geneve_hc.self_link

  backends = { for k, v in module.vmseries : k => v.instance_group_self_link }
}

module "nsi" {
  source = "../../modules/nsi_intercept"

  project_id             = var.project
  name_prefix            = var.name_prefix
  producer_vpc_self_link = module.data_vpc.network.self_link

  zonal_forwarding_rules = {
    for fw_key, fw in var.vmseries : fw.zone => module.geneve_ilb[fw_key].forwarding_rule
  }

  consumer_vpcs = {
    for k, v in module.consumer_vpcs : k => {
      self_link = v.network.self_link
    }
  }

  firewall_policy_rules = var.firewall_policy_rules
}

module "ncc" {
  count  = var.enable_ncc ? 1 : 0
  source = "../../modules/ncc_connectivity"

  project_id  = var.project
  name_prefix = var.name_prefix
  topology    = var.ncc_topology

  vpc_spokes = {
    for k, v in module.consumer_vpcs : k => {
      vpc_self_link = v.network.self_link
    }
  }
}

resource "google_compute_instance" "linux_vms" {
  for_each = var.linux_vms

  name         = "${var.name_prefix}${each.key}"
  zone         = each.value.zone
  project      = var.project
  machine_type = each.value.machine_type

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = each.value.disk_size_gb
    }
  }

  network_interface {
    subnetwork = module.consumer_vpcs[each.value.consumer_vpc_key].subnetworks["default"].self_link
  }

  metadata_startup_script = each.value.metadata_startup_script

  service_account {
    email  = module.iam_service_account.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.consumer_vpcs), each.value.consumer_vpc_key)
      error_message = "linux_vms[\"${each.key}\"].consumer_vpc_key=\"${each.value.consumer_vpc_key}\" does not match any key in var.consumer_vpcs."
    }
  }
}
