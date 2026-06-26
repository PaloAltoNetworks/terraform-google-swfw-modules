output "security_profile_group_id" {
  description = "Full resource ID of the security_profile_group. Use to add additional firewall policy rules outside Terraform."
  value       = local.security_profile_group_id
}

output "endpoint_group_id" {
  description = "Full resource ID of the intercept endpoint group."
  value       = google_network_security_intercept_endpoint_group.this.id
}

output "deployment_group_id" {
  description = "Full resource ID of the intercept deployment group."
  value       = google_network_security_intercept_deployment_group.this.id
}

output "endpoint_group_association_ids" {
  description = "Map of consumer-vpc-key => endpoint_group_association resource ID."
  value       = { for k, v in google_network_security_intercept_endpoint_group_association.this : k => v.id }
}

output "intercept_deployment_ids" {
  description = "Map of zone => zonal intercept_deployment resource ID."
  value       = { for k, v in google_network_security_intercept_deployment.this : k => v.id }
}
