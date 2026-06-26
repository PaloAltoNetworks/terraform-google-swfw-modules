output "hub_id" {
  description = "Full resource ID of the NCC hub (created or pre-existing)."
  value       = local.hub_id
}

output "hub_name" {
  description = "Name of the NCC hub."
  value       = local.hub_name
}

output "spoke_names" {
  description = "Map of spoke-key => spoke resource name."
  value       = { for k, v in google_network_connectivity_spoke.this : k => v.name }
}

output "spoke_ids" {
  description = "Map of spoke-key => spoke full resource ID."
  value       = { for k, v in google_network_connectivity_spoke.this : k => v.id }
}
