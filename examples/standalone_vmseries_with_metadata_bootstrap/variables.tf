# General
variable "project" {
  description = "The project name to deploy the infrastructure in to."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "A string to prefix resource namings"
  type        = string
  default     = ""
}

# VPC
variable "networks" {
  description = <<-EOF
    A map containing each network setting.

    Example of variable deployment :

    ```
    networks = {
      "vmseries-vpc" = {
        vpc_name                        = "firewall-vpc"
        create_network                  = true
        delete_default_routes_on_create = "false"
        mtu                             = "1460"
        routing_mode                    = "REGIONAL"
        subnetworks = {
          "vmseries-sub" = {
            name              = "vmseries-subnet"
            create_subnetwork = true
            ip_cidr_range     = "172.21.21.0/24"
            region            = "us-central1"
          }
        }
        firewall_rules = {
          "allow-vmseries-ingress" = {
            name             = "vmseries-mgmt"
            source_ranges    = ["1.1.1.1/32", "2.2.2.2/32"]
            priority         = "1000"
            allowed_protocol = "all"
            allowed_ports    = []
          }
        }
      }
    ```

    For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc#input_networks)

    Multiple keys can be added and will be deployed by the code
    EOF
}

variable "vmseries" {
  description = <<-EOF
  A map containing each individual vmseries setting.

  Example of variable deployment :

  ```
    vmseries = {
      "fw-vmseries-01" = {
        name             = "fw-vmseries-01"
        zone             = "us-central1-b"
        vmseries_image   = "vmseries-flex-byol-10210h9"
        ssh_keys         = "admin:<YOUR_SSH_KEY>"
        machine_type     = "n2-standard-4"
        min_cpu_platform = "Intel Cascade Lake"
        tags             = ["vmseries"]
        scopes = [
          "https://www.googleapis.com/auth/compute.readonly",
          "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
          "https://www.googleapis.com/auth/devstorage.read_only",
          "https://www.googleapis.com/auth/logging.write",
          "https://www.googleapis.com/auth/monitoring.write",
        ]
        bootstrap_options = {
          panorama-server = "1.1.1.1" # Modify this value as per deployment requirements
          dns-primary     = "8.8.8.8" # Modify this value as per deployment requirements
          dns-secondary   = "8.8.4.4" # Modify this value as per deployment requirements
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
        network_interfaces = [
          {
            vpc_network_key  = "vmseries-vpc"
            subnetwork_key   = "fw-mgmt-sub"
            private_ip       = "10.10.10.2"
            create_public_ip = true
          }
        ]
      }
    }
  ```
  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vmseries#inputs)

  The bootstrap_template_map contains variables that will be applied to the bootstrap template. Each firewall Day 0 bootstrap will be parametrised based on these inputs.
  Multiple keys can be added and will be deployed by the code.

  EOF
}

variable "vmseries_common" {
  description = <<-EOF
  A map containing common vmseries setting.

  Example of variable deployment :

  ```
  vmseries_common = {
    ssh_keys            = "admin:AAAABBBB..."
    vmseries_image      = "vmseries-flex-byol-10210h9"
    machine_type        = "n2-standard-4"
    min_cpu_platform    = "Intel Cascade Lake"
    service_account_key = "sa-vmseries-01"
    bootstrap_options = {
      type                = "dhcp-client"
      mgmt-interface-swap = "enable"
    }
  }
  ``` 

  Bootstrap options can be moved between vmseries individual instance variable (`vmseries`) and this common vmserie variable (`vmseries_common`).
  EOF
  default     = {}
}
