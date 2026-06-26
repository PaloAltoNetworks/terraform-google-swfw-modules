variable "project" {
  type        = string
  description = "GCP project ID for all resources."
}

variable "region" {
  type        = string
  description = "GCP region for subnets, ILBs, and Cloud Router."
}

variable "name_prefix" {
  type        = string
  description = "Short prefix applied to every resource name (e.g. \"pan-nsi-\")."
}


variable "service_account" {
  type = object({
    service_account_id = string
    roles              = list(string)
  })
  default = {
    service_account_id = "sa-ngfw-vmseries"
    roles = [
      "roles/compute.networkViewer",
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/stackdriver.accounts.viewer",
      "roles/stackdriver.resourceMetadata.writer",
    ]
  }
  description = "Service account configuration for the VM-Series instances."
}


variable "ssh_keys" {
  type        = string
  sensitive   = true
  description = "SSH public key(s) for instance-level access (format: \"user:ssh-ed25519 AAAA... user@host\")."
}

variable "vmseries_image" {
  type        = string
  description = "Full VM-Series image name. Must be PAN-OS >= 11.2 for NSI GENEVE support (e.g. \"vmseries-flex-byol-1120\")."
}

variable "create_mgmt_public_ip" {
  type        = bool
  default     = false
  description = "Assign a public IP to the mgmt NIC. Set true in lab environments for direct SSH/HTTPS access."
}

variable "vmseries_common" {
  type = object({
    machine_type     = optional(string, "n2-standard-8")
    min_cpu_platform = optional(string, "Intel Cascade Lake")
    bootstrap_options = optional(map(string), {
      type                        = "dhcp-client"
      dhcp-send-client-id         = "yes"
      dhcp-accept-server-hostname = "yes"
      dhcp-accept-server-domain   = "yes"
      dns-primary                 = "169.254.169.254"
      panorama-server             = ""
    })
  })
  default     = {}
  description = <<-EOT
    Common settings shared across all VM-Series instances.
    The bootstrap option `plugin-op-commands = "geneve-inspect:enable"` is always
    merged in automatically — do not include it here as it would be overwritten.
  EOT
}

variable "vmseries" {
  type = map(object({
    zone              = string
    bootstrap_options = optional(map(string), {})
  }))
  description = <<-EOT
    Map of VM-Series instance key => zone and per-instance bootstrap overrides.
    Typically two entries (one per zone) for zone-redundant active-active deployment.
    The module forces `plugin-op-commands = "geneve-inspect:enable"` in the merged
    bootstrap_options regardless of what is set here.
    Each entry must use a unique zone — NSI requires one ILB forwarding rule per zone,
    and the example maps zone => forwarding rule one-to-one.
  EOT

  validation {
    condition     = length(values(var.vmseries)[*].zone) == length(distinct(values(var.vmseries)[*].zone))
    error_message = "Every vmseries entry must be in a unique zone."
  }
}


variable "mgmt_vpc" {
  type = object({
    name            = string
    subnetwork_name = string
    ip_cidr_range   = string
    firewall_rules = optional(map(object({
      name             = string
      source_ranges    = optional(list(string))
      source_tags      = optional(list(string))
      allowed_protocol = string
      allowed_ports    = optional(list(string), [])
      priority         = optional(number, 1000)
    })), {})
  })
  description = "Management VPC for VM-Series NIC0. Kept separate from data_vpc so GCP health checks target NIC1."
}

variable "data_vpc" {
  type = object({
    name            = string
    subnetwork_name = string
    ip_cidr_range   = string
    firewall_rules = optional(map(object({
      name             = string
      source_ranges    = optional(list(string))
      source_tags      = optional(list(string))
      allowed_protocol = string
      allowed_ports    = optional(list(string), [])
      priority         = optional(number, 1000)
    })), {})
  })
  description = "Data/GENEVE VPC for VM-Series NIC1. The GENEVE ILB and NSI intercept deployment group live here."
}


variable "consumer_vpcs" {
  type = map(object({
    name            = string
    subnetwork_name = string
    ip_cidr_range   = string
    firewall_rules = optional(map(object({
      name             = string
      source_ranges    = optional(list(string))
      source_tags      = optional(list(string))
      allowed_protocol = string
      allowed_ports    = optional(list(string), [])
      priority         = optional(number, 1000)
    })), {})
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
  description = "Map of consumer/spoke VPC key => VPC and subnet configuration. Each entry gets one NCC spoke and one NSI endpoint-group association."
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
        dest_ip_ranges = ["0.0.0.0/0"]
        layer4_configs = [{ ip_protocol = "all" }]
      }
    },
    {
      priority    = 1001
      direction   = "INGRESS"
      description = "Intercept all ingress for PAN-OS inspection"
      match = {
        src_ip_ranges  = ["0.0.0.0/0"]
        layer4_configs = [{ ip_protocol = "all" }]
      }
    },
  ]
  description = "Firewall policy rules applied to each consumer VPC. The nsi_intercept module sets action=apply_security_profile_group automatically."
}


variable "enable_ncc" {
  type        = bool
  default     = true
  description = "Deploy a Network Connectivity Center hub and attach each consumer VPC as a spoke. When true, all consumer VPCs gain transitive (MESH) routing through the hub, which NSI then inspects. Set false to skip NCC entirely and manage connectivity separately."
}

variable "ncc_topology" {
  type        = string
  default     = "MESH"
  description = "NCC hub preset topology. MESH allows all spokes to reach each other; STAR requires designating center spokes."

  validation {
    condition     = contains(["MESH", "STAR"], var.ncc_topology)
    error_message = "ncc_topology must be MESH or STAR."
  }
}


variable "linux_vms" {
  type = map(object({
    zone                    = string
    consumer_vpc_key        = string
    machine_type            = optional(string, "e2-micro")
    disk_size_gb            = optional(number, 20)
    metadata_startup_script = optional(string, null)
  }))
  default     = {}
  description = "Optional Linux test VMs to deploy in consumer VPCs for validating NSI traffic interception end-to-end."
}
