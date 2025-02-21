output "pubsub_topic_id" {
  description = "The resource ID of the Pub/Sub Topic."
  value       = try({ for k, v in module.autoscale : k => v.pubsub_topic_id }, null)
}

output "pubsub_subscription_id" {
  description = "The resource ID of the Pub/Sub Subscription."
  value       = try({ for k, v in module.autoscale : k => v.pubsub_subscription_id }, null)
}

output "lbs_internal_ips" {
  description = "Private IP addresses of internal network loadbalancers."
  value       = { for k, v in module.lb_internal : k => v.address }
}

output "lbs_external_ips" {
  description = "Public IP addresses of external network loadbalancers."
  value       = { for k, v in module.lb_external : k => v.ip_addresses }
}

output "linux_vm_ips" {
  description = "Private IP addresses of Linux VMs."
  value       = { for k, v in resource.google_compute_instance.linux_vm : k => v.network_interface[0].network_ip }
}
