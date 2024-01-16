# General
variable "project" {
  description = "The project name to deploy the infrastructure in to."
  type        = string
  default     = null
}
variable "region" {
  description = "The region into which to deploy the infrastructure in to"
  type        = string
  default     = "us-central1"
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
      "panorama-vpc" = {
        vpc_name                        = "firewall-vpc"
        create_network                  = true
        delete_default_routes_on_create = "false"
        mtu                             = "1460"
        routing_mode                    = "REGIONAL"
        subnetworks = {
          "panorama-sub" = {
            name              = "panorama-subnet"
            create_subnetwork = true
            ip_cidr_range     = "172.21.21.0/24"
            region            = "us-central1"
          }
        }
        firewall_rules = {
          "allow-panorama-ingress" = {
            name             = "panorama-mgmt"
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

# Panorama
variable "panoramas" {
  description = <<-EOF
    A map containing each panorama setting.

    Example of variable deployment :

    ```
    panoramas = {
      "panorama-01" = {
        panorama_name     = "panorama-01"
        panorama_vpc      = "panorama-vpc"
        panorama_subnet   = "panorama-subnet"
        panorama_version  = "panorama-byol-1000"
        ssh_keys          = "admin:PUBLIC-KEY"
        attach_public_ip  = true
        private_static_ip = "172.21.21.2"
      }
    }
    ```
  
    For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/panorama#inputs)

    Multiple keys can be added and will be deployed by the code
    EOF
}
