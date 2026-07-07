variable "project_id" {
  type        = string
  description = "GCP project ID where NSI resources will be created."
}

variable "name_prefix" {
  type        = string
  description = "Short prefix applied to every resource name."
}

variable "producer_vpc_self_link" {
  type        = string
  description = "Self-link of the producer/security VPC — used as the intercept deployment group network."
}

variable "zonal_forwarding_rules" {
  type        = map(string)
  description = <<-EOT
    Map of zone => ILB forwarding-rule self-link. google_network_security_intercept_deployment is zone-level
    (not regional), so one entry per FW zone is required. Multiple zones in the same region share the same
    regional ILB forwarding rule.
  EOT
}

variable "consumer_vpcs" {
  type = map(object({
    self_link  = string
    project_id = optional(string, null)
    firewall_policy_rules = optional(list(object({
      priority    = number
      direction   = string
      description = optional(string, "")
      match = object({
        src_ip_ranges  = optional(list(string), [])
        dest_ip_ranges = optional(list(string), [])
        layer4_configs = list(object({
          ip_protocol = string
          ports       = optional(list(string), [])
        }))
      })
    })), null)
  }))
  description = <<-EOT
    Consumer VPCs to protect. Map of vpc-key => { self_link, project_id, firewall_policy_rules }.
    project_id must be set when the consumer VPC is in a different project than
    var.project_id — GCP requires the intercept_endpoint_group_association to be
    created in the same project as the consumer VPC network.
    firewall_policy_rules overrides the global var.firewall_policy_rules for this specific VPC.
  EOT
}

variable "firewall_policy_rules" {
  type = list(object({
    priority    = number
    direction   = string
    description = optional(string, "")
    match = object({
      src_ip_ranges  = optional(list(string), [])
      dest_ip_ranges = optional(list(string), [])
      layer4_configs = list(object({
        ip_protocol = string
        ports       = optional(list(string), [])
      }))
    })
  }))
  default = [
    {
      priority    = 1000
      direction   = "EGRESS"
      description = "Intercept all egress for PAN-OS inspection"
      match = {
        src_ip_ranges  = []
        dest_ip_ranges = ["0.0.0.0/0"]
        layer4_configs = [{ ip_protocol = "all" }]
      }
    }
  ]
  description = "Rules applied to each consumer VPC's global network firewall policy. The module automatically sets action=apply_security_profile_group."

  validation {
    condition     = alltrue([for r in var.firewall_policy_rules : contains(["INGRESS", "EGRESS"], r.direction)])
    error_message = "Every firewall_policy_rules[*].direction must be either \"INGRESS\" or \"EGRESS\"."
  }
}

variable "create_security_profile" {
  type        = bool
  default     = true
  description = "Create the security_profile and security_profile_group. Set false to reuse an existing profile group."
}

variable "existing_security_profile_group_id" {
  type        = string
  default     = null
  description = "Full ID of an existing security_profile_group. Required when create_security_profile = false."
}
