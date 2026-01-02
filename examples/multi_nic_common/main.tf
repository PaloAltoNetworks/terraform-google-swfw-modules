module "iam_service_account" {
  source = "../../modules/iam_service_account"

  for_each = var.service_accounts

  service_account_id = "${var.name_prefix}${each.value.service_account_id}"
  display_name       = "${var.name_prefix}${each.value.display_name}"
  roles              = each.value.roles
  project_id         = var.project
}

resource "local_file" "bootstrap_xml" {

  for_each = { for k, v in var.vmseries : k => v
    if can(v.bootstrap_template_map)
  }

  filename = "files/${each.key}/config/bootstrap.xml"
  content = templatefile("templates/bootstrap_common.tmpl",
    {
      spoke1_gcp_router_ip  = each.value.bootstrap_template_map.spoke1_gcp_router_ip
      spoke2_gcp_router_ip  = each.value.bootstrap_template_map.spoke2_gcp_router_ip
      private_network_cidr  = each.value.bootstrap_template_map.private_network_cidr
      untrust_gcp_router_ip = each.value.bootstrap_template_map.untrust_gcp_router_ip
      spoke1_loopback_ip    = each.value.bootstrap_template_map.spoke1_loopback_ip
      spoke2_loopback_ip    = each.value.bootstrap_template_map.spoke2_loopback_ip
      untrust_loopback_ip   = each.value.bootstrap_template_map.untrust_loopback_ip
    }
  )
}

resource "local_sensitive_file" "init_cfg" {

  for_each = { for k, v in var.vmseries : k => v
    if can(v.bootstrap_template_map)
  }

  filename = "files/${each.key}/config/init-cfg.txt"
  content = templatefile(
    "templates/init-cfg.tmpl",
    { bootstrap_options = merge(var.vmseries_common.bootstrap_options, each.value.bootstrap_options) }
  )
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  for_each = var.bootstrap_buckets

  folders = keys(var.vmseries)

  name_prefix     = "${var.name_prefix}${each.value.bucket_name_prefix}"
  service_account = module.iam_service_account[each.value.service_account_key].email
  location        = each.value.location
  files = merge(
    { for k, v in var.vmseries : "files/${k}/config/bootstrap.xml" => "${k}/config/bootstrap.xml" if can(v.bootstrap_template_map) },
    { for k, v in var.vmseries : "files/${k}/config/init-cfg.txt" => "${k}/config/init-cfg.txt" if can(v.bootstrap_template_map) },
  )
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

resource "google_compute_route" "this" {

  for_each = var.routes

  name         = "${var.name_prefix}${each.value.name}"
  dest_range   = each.value.destination_range
  network      = module.vpc[each.value.vpc_network_key].network.self_link
  next_hop_ilb = module.lb_internal[each.value.lb_internal_key].forwarding_rule
  priority     = 100
}

module "vpc_peering" {
  source = "../../modules/vpc-peering"

  for_each = var.vpc_peerings

  local_network = module.vpc[each.value.local_network_key].network.id
  peer_network  = module.vpc[each.value.peer_network_key].network.id

  local_export_custom_routes                = each.value.local_export_custom_routes
  local_import_custom_routes                = each.value.local_import_custom_routes
  local_export_subnet_routes_with_public_ip = each.value.local_export_subnet_routes_with_public_ip
  local_import_subnet_routes_with_public_ip = each.value.local_import_subnet_routes_with_public_ip

  peer_export_custom_routes                = each.value.peer_export_custom_routes
  peer_import_custom_routes                = each.value.peer_import_custom_routes
  peer_export_subnet_routes_with_public_ip = each.value.peer_export_subnet_routes_with_public_ip
  peer_import_subnet_routes_with_public_ip = each.value.peer_import_subnet_routes_with_public_ip
}

module "vmseries" {
  source = "../../modules/vmseries"

  for_each = var.vmseries

  name                  = "${var.name_prefix}${each.value.name}"
  zone                  = each.value.zone
  service_account       = try(module.iam_service_account[each.value.service_account_key].email, module.iam_service_account[var.vmseries_common.service_account_key].email)
  scopes                = coalesce(each.value.scopes, var.vmseries_common.scopes, [])
  ssh_keys              = coalesce(each.value.ssh_keys, var.vmseries_common.ssh_keys)
  vmseries_image        = coalesce(each.value.vmseries_image, var.vmseries_common.vmseries_image)
  machine_type          = coalesce(each.value.machine_type, var.vmseries_common.machine_type)
  min_cpu_platform      = coalesce(each.value.min_cpu_platform, var.vmseries_common.min_cpu_platform)
  tags                  = coalesce(each.value.tags, var.vmseries_common.tags)
  create_instance_group = true

  named_ports = try(each.value.named_ports, [])

  network_interfaces = [for v in each.value.network_interfaces :
    {
      subnetwork       = module.vpc[v.vpc_network_key].subnetworks[v.subnetwork_key].self_link
      private_ip       = v.private_ip
      create_public_ip = try(v.create_public_ip, false)
      public_ip        = try(v.public_ip, null)
      public_ip_region = try(v.public_ip_region, var.region)
    }
  ]

  bootstrap_options = try(
    merge(
      { vmseries-bootstrap-gce-storagebucket = "${module.bootstrap[each.value.bootstrap_bucket_key].bucket_name}/${each.key}/" },
      var.vmseries_common.bootstrap_options
    ),
    merge(
      try(var.vmseries_common.bootstrap_options, {}),
      try(each.value.bootstrap_options, {})
    )
  )
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

  metadata = {
    enable-oslogin = true
  }


  service_account {
    email  = module.iam_service_account[each.value.service_account_key].email
    scopes = each.value.scopes
  }
}

module "lb_internal" {
  source = "../../modules/lb_internal"

  for_each = var.lbs_internal

  name              = "${var.name_prefix}${each.value.name}"
  region            = var.region
  health_check_port = try(each.value.health_check_port, "80")
  backends          = { for v in each.value.backends : v => module.vmseries[v].instance_group_self_link }
  ip_address        = each.value.ip_address
  subnetwork        = module.vpc[each.value.vpc_network_key].subnetworks[each.value.subnetwork_key].self_link
  network           = module.vpc[each.value.vpc_network_key].network.self_link
  all_ports         = true
}

module "lb_external" {
  source = "../../modules/lb_external"

  for_each = var.lbs_external

  project = var.project

  name                    = "${var.name_prefix}${each.value.name}"
  backend_instance_groups = { for v in each.value.backends : v => module.vmseries[v].instance_group_self_link }
  rules                   = { for k, v in each.value.rules : "${var.name_prefix}${k}" => v }

  health_check_http_port         = each.value.http_health_check_port
  health_check_http_request_path = try(each.value.http_health_check_request_path, "/php/login.php")
}
