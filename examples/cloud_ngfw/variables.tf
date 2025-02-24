variable "project" {
  description = "The project name to deploy the infrastructure in to."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "A string to prefix resource namings."
  type        = string
  default     = "example-"
}

variable "org_id" {
  description = "Organization ID where the Firewall Endpoint will be created."
  type        = string
}

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
  type = map(object({
    vpc_name                        = string
    create_network                  = optional(bool, true)
    delete_default_routes_on_create = optional(bool, false)
    enable_ula_internal_ipv6        = optional(bool, false)
    internal_ipv6_range             = optional(string, "")
    mtu                             = optional(number, 1460)
    routing_mode                    = optional(string, "REGIONAL")
    subnetworks = map(object({
      name              = string
      create_subnetwork = optional(bool, true)
      ip_cidr_range     = string
      region            = string
      stack_type        = optional(string)
      log_config = optional(object({
        aggregation_interval = optional(string)
        flow_sampling        = optional(string)
        metadata             = optional(string)
        metadata_fields      = optional(list(string))
        filter_expr          = optional(string)
      }))
    }))
    firewall_rules = optional(map(object({
      name                    = string
      source_ranges           = optional(list(string))
      source_tags             = optional(list(string))
      source_service_accounts = optional(list(string))
      allowed_protocol        = string
      allowed_ports           = list(string)
      priority                = optional(string)
      target_service_accounts = optional(list(string))
      target_tags             = optional(list(string))
      log_metadata            = optional(string)
    })))
    }
  ))
}

variable "cloud_nats" {
  description = <<-EOF
    A map containing the Cloud NAT configuration settings.

    Example of variable deployment:

    ```
    cloud_nats = {
        fw-autoscale-usc1-nat = {
            name                           = "fw-autoscale-usc1-nat"
            region                         = "us-central1"
            router_name                    = "fw-autoscale-usc1-nat-router"
            vpc_network_key                = "fw-untrust-vpc"
            min_ports_per_vm               = 1024
            max_ports_per_vm               = 4096
            enable_dynamic_port_allocation = true
            log_config_enable              = true
            subnetworks = [
            {
                subnetwork_key = "fw-untrust-usc1-sub"
            }
            ]
        }
    }
    ```

    For a full list of available configuration items - please visit https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/5.3.0

    Multiple keys can be added and will be deployed by the code.

    EOF

  type = map(object({
    name                           = string
    region                         = string
    router_name                    = string
    vpc_network_key                = string
    min_ports_per_vm               = optional(number, 1024)
    max_ports_per_vm               = optional(number, 4096)
    enable_dynamic_port_allocation = optional(bool, true)
    log_config_enable              = optional(bool, true)
    subnetworks = list(object({
      subnetwork_key = string
    }))
    }
  ))
}

variable "firewall_endpoints" {
  description = <<-EOF

  A map containing the Cloud Firewall Endpoints configuration settings.

  Example of variable deployment:

  ```
    firewall_endpoints = {
        endpoint_a = {
            firewall_endpoint_name             = "endpoint-new-a"
            org_id                             = "12345"
            zone                               = "us-central1-a"
            billing_project_id                 = "ngfwtest-billing-project"
            firewall_endpoint_association_name = "fwe-assoc-new-a"
            project_id                         = "ngfwtest-billing-project"
        }
    }
  ```

  EOF
  type = map(object({
    firewall_endpoint_name             = string
    zone                               = string
    firewall_endpoint_association_name = string
    tls_inspection_policy              = optional(string)
    vpc_network_key                    = string
  }))
}

variable "network_security_profiles" {
  description = <<-EOF

  A map containing the network security profile configuration settings.

  Example of variable deployment:
  ```
  profile-a = {
    profile_name              = "profile-a"
    profile_group_name        = "group-profile-a"
    org_id                    = "12345"
    profile_description       = "My Profile"
    profile_group_description = "My Profile Group"
    severity_overrides = {
      "LOW"           = "DENY"
      "INFORMATIONAL" = "ALERT"
      "MEDIUM"        = "DENY"
      "HIGH"          = "DENY"
      "CRITICAL"      = "DENY"
    }
  }
  ```
  EOF
  type = map(object({
    profile_name              = string
    profile_group_name        = string
    profile_description       = optional(string, null)
    profile_group_description = optional(string, null)
    labels                    = optional(map(string), null)
    location                  = optional(string, "global")
    severity_overrides        = optional(map(string), {})
    threat_overrides          = optional(map(string), {})
  }))
}

variable "network_policies" {
  description = <<-EOF

  A map containing the network policy configuration settings.

  A single policy is created and used but multile rules can be added - both ingress and egress.

  Example of variable deployment:
  
  ```
    network_policies = {
        policy_name = "network-policy-a"
        description = "This is a network policy for the ngfw project"
        project_id  = "ngfwtest-project"
        network_associations = {
            "assoc-1" = {
                policy_association_name = "network-policy-a-assoc"
                vpc_network_key         = "network-a"
            }
            "assoc-2" = {
                policy_association_name = "network-policy-b-assoc"
                vpc_network_key         = "network-b"
            }
        }
        rules = {
            "allow_some_ingress" = {
                rule_name          = "allow_some_ingress"
                description        = "Allow some ingress traffic"
                direction          = "INGRESS"
                enable_logging     = true
                tls_inspect        = false
                priority           = 100
                action             = "apply_security_profile_group"
                security_group_key = "profile-a"
                dest_ip_ranges     = ["10.0.0.0/24"]
                src_ip_ranges      = ["0.0.0.0/0"]
                ip_protocol        = "all"
            }
            "allow_some_egress" = {
                rule_name          = "allow_some_egress"
                description        = "Allow some egress traffic"
                direction          = "EGRESS"
                enable_logging     = true
                tls_inspect        = false
                priority           = 101
                action             = "apply_security_profile_group"
                security_group_key = "profile-a"
                dest_ip_ranges     = ["0.0.0.0/0"]
                src_ip_ranges      = ["10.0.0.0/24"]
                ip_protocol        = "all"
            }
        }
    }
  ```
  EOF
  type = object({
    policy_name = string
    description = optional(string, null)
    network_associations = map(object({
      policy_association_name = string
      vpc_network_key         = string
    }))
    rules = map(object({
      rule_name               = string
      description             = optional(string, null)
      direction               = string
      enable_logging          = optional(bool, false)
      tls_inspect             = optional(bool, false)
      priority                = optional(number, 100)
      action                  = string
      security_group_key      = optional(string)
      target_service_accounts = optional(list(string))
      disabled                = optional(bool, false)
      target_secure_tags = optional(map(object({
        name = string
      })), {})
      src_secure_tags = optional(map(object({
        name = string
      })), {})
      src_ip_ranges             = optional(list(string))
      dest_ip_ranges            = optional(list(string))
      src_address_groups        = optional(list(string))
      dest_address_groups       = optional(list(string))
      src_fqdns                 = optional(list(string))
      dest_fqdns                = optional(list(string))
      src_region_codes          = optional(list(string))
      dest_region_codes         = optional(list(string))
      src_threat_intelligences  = optional(list(string))
      dest_threat_intelligences = optional(list(string))
      ip_protocol               = string
      ports                     = optional(list(string))
    }))
  })
}

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
    }
  }
  ```
  EOF
  type = map(object({
    linux_machine_type      = string
    zone                    = string
    linux_disk_size         = string
    vpc_network_key         = string
    subnetwork_key          = string
    private_ip              = string
    scopes                  = list(string)
    metadata_startup_script = optional(string, null)
  }))
}
