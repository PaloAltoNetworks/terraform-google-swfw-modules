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

module "vmseries" {
  source = "../../modules/vmseries"

  for_each = var.vmseries

  name                  = "${var.name_prefix}${each.value.name}"
  zone                  = each.value.zone
  ssh_keys              = try(each.value.ssh_keys, var.vmseries_common.ssh_keys)
  vmseries_image        = try(each.value.vmseries_image, var.vmseries_common.vmseries_image)
  machine_type          = try(each.value.machine_type, var.vmseries_common.machine_type)
  min_cpu_platform      = try(each.value.min_cpu_platform, var.vmseries_common.min_cpu_platform, "Intel Cascade Lake")
  tags                  = try(each.value.tags, var.vmseries_common.tags, [])
  scopes                = try(each.value.scopes, var.vmseries_common.scopes, [])
  create_instance_group = true

  bootstrap_options = try(each.value.bootstrap_options, {})

  named_ports = try(each.value.named_ports, [])

  network_interfaces = [for v in each.value.network_interfaces :
    {
      subnetwork       = module.vpc[v.vpc_network_key].subnetworks[v.subnetwork_key].self_link
      private_ip       = v.private_ip
      create_public_ip = try(v.create_public_ip, false)
      public_ip        = try(v.public_ip, null)
      public_ip_region = try(v.public_ip_region, null)
  }]
}
