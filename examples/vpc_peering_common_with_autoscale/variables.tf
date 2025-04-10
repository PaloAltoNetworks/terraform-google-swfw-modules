# General
variable "project" {
  description = "The project name to deploy the infrastructure in to."
  type        = string
  default     = null
}

variable "region" {
  description = "The region into which to deploy the infrastructure in to."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "A string to prefix resource namings."
  type        = string
  default     = "example-"
}

# Service Account
variable "service_accounts" {
  description = <<-EOF
  A map containing each service account setting.

  Example of variable deployment :
    ```
  service_accounts = {
    "sa-vmseries-01" = {
      service_account_id = "sa-vmseries-01"
      display_name       = "VM-Series SA"
      roles = [
        "roles/compute.networkViewer",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
        "roles/viewer"
      ]
    }
  }
  ```
  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/iam_service_account#Inputs)

  Multiple keys can be added and will be deployed by the code.

  EOF
  type        = map(any)
  default     = {}
}

# VPC
variable "networks" {
  description = <<-EOF
  A map containing each network setting.

  Example of variable deployment :

  ```
  networks = {
    fw-mgmt-vpc = {
      vpc_name = "fw-mgmt-vpc"
      create_network = true
      delete_default_routes_on_create = false
      mtu = "1460"
      routing_mode = "REGIONAL"
      subnetworks = {
        fw-mgmt-sub = {
          name = "fw-mgmt-sub"
          create_subnetwork = true
          ip_cidr_range = "10.10.10.0/28"
          region = "us-east1"
        }
      }
      firewall_rules = {
        allow-mgmt-ingress = {
          name = "allow-mgmt-ingress"
          source_ranges = ["10.10.10.0/24"]
          priority = "1000"
          allowed_protocol = "all"
          allowed_ports = []
        }
      }
    }
  }
  ```

  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc#input_networks)

  Multiple keys can be added and will be deployed by the code.
  EOF
  type        = any
  default     = {}
}

variable "vpc_peerings" {
  description = <<-EOF
  A map containing each VPC peering setting.

  Example of variable deployment :

  ```
  vpc_peerings = {
    "trust-to-spoke1" = {
      local_network_key = "fw-trust-vpc"
      peer_network_key  = "fw-spoke1-vpc"

      local_export_custom_routes                = true
      local_import_custom_routes                = true
      local_export_subnet_routes_with_public_ip = true
      local_import_subnet_routes_with_public_ip = true

      peer_export_custom_routes                = true
      peer_import_custom_routes                = true
      peer_export_subnet_routes_with_public_ip = true
      peer_import_subnet_routes_with_public_ip = true
    }
  }
  ```
  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc-peering#inputs)

  Multiple keys can be added and will be deployed by the code.
  EOF
  type        = map(any)
  default     = {}
}

variable "routes" {
  description = <<-EOF
  A map containing each route setting. Note that you can only add routes using a next-hop type of internal load-balance rule.

  Example of variable deployment :

  ```
  routes = {
    "default-route-trust" = {
      name = "fw-default-trust"
      destination_range = "0.0.0.0/0"
      vpc_network_key = "fw-trust-vpc"
      lb_internal_name = "internal-lb"
    }
  }
  ```

  Multiple keys can be added and will be deployed by the code.
  EOF
  type        = map(any)
  default     = {}
}

# Autoscale
variable "autoscale_regional_mig" {
  description = <<-EOF
  Sets the managed instance group type to either a regional (if `true`) or a zonal (if `false`).
  For more information please see [About regional MIGs](https://cloud.google.com/compute/docs/instance-groups/regional-migs#why_choose_regional_managed_instance_groups).
  EOF
  type        = bool
  default     = true
}

variable "autoscale_common" {
  type = object({
    ssh_keys            = optional(string)
    image               = optional(string)
    machine_type        = optional(string)
    min_cpu_platform    = optional(string)
    disk_type           = optional(string)
    tags                = optional(list(string))
    service_account_key = optional(string)
    scopes              = optional(list(string))
    named_ports = optional(list(object({
      name = string
      port = number
    })))
    min_vmseries_replicas            = optional(number)
    max_vmseries_replicas            = optional(number)
    update_policy_type               = optional(string)
    cooldown_period                  = optional(number)
    scale_in_control_replicas_fixed  = optional(number)
    scale_in_control_time_window_sec = optional(number)
    autoscaler_metrics = optional(map(object({
      target = optional(string)
      type   = optional(string)
      filter = optional(string)
    })))
    bootstrap_options = optional(object({
      type                                  = optional(string)
      mgmt-interface-swap                   = optional(string)
      plugin-op-commands                    = optional(string)
      panorama-server                       = optional(string)
      auth-key                              = optional(string)
      dgname                                = optional(string)
      tplname                               = optional(string)
      dhcp-send-hostname                    = optional(string)
      dhcp-send-client-id                   = optional(string)
      dhcp-accept-server-hostname           = optional(string)
      dhcp-accept-server-domain             = optional(string)
      authcodes                             = optional(string)
      vm-series-auto-registration-pin-id    = optional(string)
      vm-series-auto-registration-pin-value = optional(string)
    }))
    create_pubsub_topic = optional(bool)
  })
  default     = {}
  description = <<-EOF
  A map containing common vmseries autoscale settings.

  Example of variable deployment :

  ```
  vmseries_common = {
    ssh_keys            = "admin:AAAABBBB..."
    image               = "vmseries-flex-byol-1114h7"
    machine_type        = "n2-standard-4"
    min_cpu_platform    = "Intel Cascade Lake"
    service_account_key = "sa-vmseries-01"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    update_policy_type = "OPPORTUNISTIC"
    cooldown_period    = 480
    bootstrap_options = {
      type                = "dhcp-client"
      mgmt-interface-swap = "enable"
    }
  }
  ``` 

  Majority of settings can be moved between this common and individual instance (ie. `var.vmseries`) variables. If values for the same item are specified in both of them, one from the latter will take precedence.
  EOF
}

variable "autoscale" {
  type = map(object({
    name                             = string
    zones                            = optional(map(string))
    ssh_keys                         = optional(string)
    image                            = optional(string)
    machine_type                     = optional(string)
    min_cpu_platform                 = optional(string)
    disk_type                        = optional(string)
    tags                             = optional(list(string))
    service_account_key              = optional(string)
    scopes                           = optional(list(string))
    min_vmseries_replicas            = optional(number)
    max_vmseries_replicas            = optional(number)
    update_policy_type               = optional(string)
    cooldown_period                  = optional(number)
    scale_in_control_replicas_fixed  = optional(number)
    scale_in_control_time_window_sec = optional(number)
    autoscaler_metrics = optional(map(object({
      target = optional(string)
      type   = optional(string)
      filter = optional(string)
    })))
    network_interfaces = list(object({
      vpc_network_key  = string
      subnetwork_key   = string
      create_public_ip = optional(bool)
      public_ip        = optional(string)
    }))
    named_ports = optional(list(object({
      name = string
      port = number
    })))
    bootstrap_options = optional(object({
      type                                  = optional(string)
      mgmt-interface-swap                   = optional(string)
      plugin-op-commands                    = optional(string)
      panorama-server                       = optional(string)
      auth-key                              = optional(string)
      dgname                                = optional(string)
      tplname                               = optional(string)
      dhcp-send-hostname                    = optional(string)
      dhcp-send-client-id                   = optional(string)
      dhcp-accept-server-hostname           = optional(string)
      dhcp-accept-server-domain             = optional(string)
      authcodes                             = optional(string)
      vm-series-auto-registration-pin-id    = optional(string)
      vm-series-auto-registration-pin-value = optional(string)
    }))
    create_pubsub_topic = optional(bool)
  }))
  default     = {}
  description = <<-EOF
  A map containing each vmseries autoscale setting.
  Zonal or regional managed instance group type is controolled from the `autoscale_regional_mig` variable for all autoscale instances.

  Example of variable deployment :

  ```
  autoscale = {
    fw-autoscale-common = {
      name = "fw-autoscale-common"
      zones = {
        zone1 = "us-east4-b"
        zone2 = "us-east4-c"
      }
      named_ports = [
        {
          name = "http"
          port = 80
        },
        {
          name = "https"
          port = 443
        }
      ]
      service_account_key   = "sa-vmseries-01"
      min_vmseries_replicas = 2
      max_vmseries_replicas = 4
      create_pubsub_topic   = true
      autoscaler_metrics = {
        "custom.googleapis.com/VMSeries/panSessionUtilization" = {
          target = 70
        }
        "custom.googleapis.com/VMSeries/panSessionThroughputKbps" = {
          target = 700000
        }
      }
      bootstrap_options = {
        type                        = "dhcp-client"
        dhcp-send-hostname          = "yes"
        dhcp-send-client-id         = "yes"
        dhcp-accept-server-hostname = "yes"
        dhcp-accept-server-domain   = "yes"
        mgmt-interface-swap         = "enable"
        panorama-server             = "1.1.1.1"
        ssh-keys                    = "admin:<your_ssh_key>" # Replace this value with client data
      }
      network_interfaces = [
        {
          vpc_network_key  = "fw-untrust-vpc"
          subnetwork_key   = "fw-untrust-sub"
          create_public_ip = true
        },
        {
          vpc_network_key  = "fw-mgmt-vpc"
          subnetwork_key   = "fw-mgmt-sub"
          create_public_ip = true
        },
        {
          vpc_network_key = "fw-trust-vpc"
          subnetwork_key  = "fw-trust-sub"
        }
      ]
    }
  }
  ``` 
  EOF
}

# Load Balancers
variable "lbs_internal" {
  description = <<-EOF
  A map containing each internal loadbalancer setting.
  Note : private IP reservation is not by default within the example as it may overlap with autoscale IP allocation.

  Example of variable deployment :

  ```
  lbs_internal = {
    "internal-lb" = {
      name              = "internal-lb"
      health_check_port = "80"
      backends          = ["fw-vmseries-01", "fw-vmseries-02"]
      subnetwork_key    = "fw-trust-sub"
      vpc_network_key   = "fw-trust-vpc"
    }
  }
  ```
  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_internal#inputs)

  Multiple keys can be added and will be deployed by the code.
  EOF
  type        = map(any)
  default     = {}
}

variable "lbs_external" {
  description = <<-EOF
  A map containing each external loadbalancer setting.

  Example of variable deployment :

  ```
  lbs_external = {
    "external-lb" = {
      name     = "external-lb"
      backends = ["fw-vmseries-01", "fw-vmseries-02"]
      rules = {
        "all-ports" = {
          ip_protocol = "L3_DEFAULT"
        }
      }
      http_health_check_port         = "80"
      http_health_check_request_path = "/php/login.php"
    }
  }
  ```
  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_external#inputs)

  Multiple keys can be added and will be deployed by the code.
  EOF
  type        = map(any)
  default     = {}
}

# Spoke VPCs Linux VMs
variable "linux_vms" {
  description = <<-EOF
  A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.

  Example of varaible deployment:

  ```
  linux_vms = {
    spoke1-vm = {
      linux_machine_type = "n2-standard-4"
      zone               = "us-east1-b"
      linux_disk_size    = "50" # Modify this value as per deployment requirements
      vpc_network_key    = "fw-spoke1-vpc"
      subnetwork_key     = "fw-spoke1-sub"
      private_ip         = "192.168.1.2"
      scopes = [
        "https://www.googleapis.com/auth/compute.readonly",
        "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
      ]
      service_account_key = "sa-linux-01"
    }
  }
  ```
  EOF
  type        = map(any)
  default     = {}
}
