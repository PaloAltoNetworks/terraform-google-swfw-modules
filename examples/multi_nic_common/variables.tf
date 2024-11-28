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

# Bootstrap bucket

variable "bootstrap_buckets" {
  description = <<-EOF
  A map containing each bootstrap bucket setting.

  Example of variable deployment:

  ```
  bootstrap_buckets = {
    vmseries-bootstrap-bucket-01 = {
      bucket_name_prefix  = "bucket-01-"
      location            = "us"
      service_account_key = "sa-vmseries-01"
    }
  }
  ```

  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/bootstrap#Inputs)

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
          name              = "fw-mgmt-sub"
          create_subnetwork = true
          ip_cidr_range     = "10.10.10.0/28"
          region            = "us-east1"
        }
      }
      firewall_rules = {
        allow-mgmt-ingress = {
          name             = "allow-mgmt-ingress"
          source_ranges    = ["10.10.10.0/24", "1.1.1.1/32"] # Set your own management source IP range.
          priority         = "1000"
          allowed_protocol = "all"
          allowed_ports    = []
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

# VM-Series

variable "vmseries_common" {
  description = <<-EOF
  A map containing common vmseries settings.

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

  Majority of settings can be moved between this common and individual instance (ie. `var.vmseries`) variables. If values for the same item are specified in both of them, one from the latter will take precedence.
  EOF
  type        = any
  default     = {}
}

variable "vmseries" {
  description = <<-EOF
  A map containing each individual vmseries setting.

  Example of variable deployment :

  ```
  vmseries = {
    "fw-vmseries-01" = {
      name             = "fw-vmseries-01"
      zone             = "us-east1-b"
      machine_type     = "n2-standard-4"
      min_cpu_platform = "Intel Cascade Lake"
      tags                 = ["vmseries"]
      service_account_key  = "sa-vmseries-01"
      scopes = [
        "https://www.googleapis.com/auth/compute.readonly",
        "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring.write",
      ]
      bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
      bootstrap_options = {
        panorama-server = "1.1.1.1"
        dns-primary     = "8.8.8.8"
        dns-secondary   = "8.8.4.4"
      }
      bootstrap_template_map = {
        trust_gcp_router_ip   = "10.10.12.1"
        untrust_gcp_router_ip = "10.10.11.1"
        private_network_cidr  = "192.168.0.0/16"
        untrust_loopback_ip   = "1.1.1.1/32" #This is placeholder IP - you must replace it on the vmseries config with the LB public IP address after the infrastructure is deployed
        trust_loopback_ip     = "10.10.12.5/32"
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
          vpc_network_key  = "fw-untrust-vpc"
          subnetwork_key       = "fw-untrust-sub"
          private_ip       = "10.10.11.2"
          create_public_ip = true
        },
        {
          vpc_network_key  = "fw-mgmt-vpc"
          subnetwork_key       = "fw-mgmt-sub"
          private_ip       = "10.10.10.2"
          create_public_ip = true
        },
        {
          vpc_network_key = "fw-trust-vpc"
          subnetwork_key = "fw-trust-sub"
          private_ip = "10.10.12.2"
        },
      ]
    }
  }
  ```
  For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vmseries#inputs)

  The bootstrap_template_map contains variables that will be applied to the bootstrap template. Each firewall Day 0 bootstrap will be parametrised based on these inputs.
  Multiple keys can be added and will be deployed by the code.

  EOF
  type        = any
  default     = {}
}

# Load Balancers

variable "lbs_internal" {
  description = <<-EOF
  A map containing each internal loadbalancer setting.

  Example of variable deployment :

  ```
  lbs_internal = {
    "internal-lb" = {
      name              = "internal-lb"
      health_check_port = "80"
      backends          = ["fw-vmseries-01", "fw-vmseries-02"]
      ip_address        = "10.10.12.5"
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
        "https://www.googleapis.com/auth/monitoring.write",
      ]
      service_account_key = "sa-linux-01"
    }
  }
  ```
  EOF
  type        = map(any)
  default     = {}
}
