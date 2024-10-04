output "vmseries_private_ips" {
  description = "Private IPv4 addresses of the VM-Series instances."
  value       = { for k, v in module.vmseries : k => v.private_ips }
}

output "vmseries_ipv6_private_ips" {
  description = "Private IPv6 addresses of the VM-Series instances."
  value       = { for k, v in module.vmseries : k => v.ipv6_private_ips }
}

output "vmseries_public_ips" {
  description = "Public IPv4 addresses of the VM-Series instances."
  value       = { for k, v in module.vmseries : k => v.public_ips }
}

output "vmseries_ipv6_public_ips" {
  description = "Public IPv6 addresses of the VM-Series instances."
  value       = { for k, v in module.vmseries : k => v.ipv6_public_ips }
}

output "lbs_internal_ips" {
  description = "Private IP addresses of internal network loadbalancers."
  value       = { for k, v in module.lb_internal : k => try(split("/", v.address)[0], v.address, null) }
}

output "lbs_external_ips" {
  description = "Public IP addresses of external network loadbalancers."
  value = flatten([for k1, v1 in module.lb_external : [
    for k2, v2 in v1.ip_addresses : {
      (k2) = try(split("/", v2)[0], v2, null)
    }]
  ])
}

output "linux_vm_ips" {
  description = "Private IP addresses of Linux VMs."
  value       = { for k, v in resource.google_compute_instance.linux_vm : k => v.network_interface[0].network_ip }
}
