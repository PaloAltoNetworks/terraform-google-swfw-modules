output "vmseries_private_ips" {
  description = "Map of VM-Series instance key => map of NIC index => private IP address."
  value       = { for k, v in module.vmseries : k => v.private_ips }
}

output "vmseries_public_ips" {
  description = "Map of VM-Series instance key => map of NIC index => public IP address (null when not created)."
  value       = { for k, v in module.vmseries : k => v.public_ips }
}

output "geneve_ilb_addresses" {
  description = "Map of VM-Series instance key => internal IP address of the per-zone GENEVE ILB forwarding rule."
  value       = { for k, v in module.geneve_ilb : k => v.address }
}

output "nsi_endpoint_group_id" {
  description = "Full resource ID of the NSI intercept endpoint group."
  value       = module.nsi.endpoint_group_id
}

output "nsi_deployment_group_id" {
  description = "Full resource ID of the NSI intercept deployment group."
  value       = module.nsi.deployment_group_id
}

output "nsi_security_profile_group_id" {
  description = "Full resource ID of the NSI security profile group."
  value       = module.nsi.security_profile_group_id
}

output "ncc_hub_id" {
  description = "Full resource ID of the NCC hub (null when enable_ncc = false)."
  value       = var.enable_ncc ? module.ncc[0].hub_id : null
}

output "ncc_spoke_names" {
  description = "Map of consumer VPC key => NCC spoke resource name (empty when enable_ncc = false)."
  value       = var.enable_ncc ? module.ncc[0].spoke_names : {}
}

output "linux_vm_ips" {
  description = "Map of Linux VM key => internal IP address (populated only when linux_vms is configured)."
  value       = { for k, v in google_compute_instance.linux_vms : k => v.network_interface[0].network_ip }
}
