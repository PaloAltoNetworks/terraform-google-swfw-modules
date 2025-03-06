---
show_in_hub: false
---
# Palo Alto Networks VM-Series NGFW Module Example

A Terraform module example for deploying a VM-Series NGFW in GCP using the [metadata](https://docs.paloaltonetworks.com/vm-series/10-2/vm-series-deployment/bootstrap-the-vm-series-firewall/choose-a-bootstrap-method#idf6412176-e973-488e-9d7a-c568fe1e33a9) bootstrap method.

This example can be used to familarize oneself with both the VM-Series NGFW and Terraform - by default the deployment creates a single instance of virtualized firewall in a Security VPC with a management-only interface and lacks any traffic inspection.

## Bootstrap

By default, only basic bootstrap parameters are enabled. The example also provides sample settings that can be used to register the firewall to either Panorama or Strata Cloud Manager (SCM) and complete the configuration. To enable this, uncomment one of the sections in `bootstrap_options` parameter.

> SCM bootstrap is supported on PAN-OS version 11.0 and above.

## Reference

### Requirements

- `terraform`, version: >= 1.3, < 2.0



### Modules
Name | Version | Source | Description
--- | --- | --- | ---
`vpc` | - | ../../modules/vpc | 
`vmseries` | - | ../../modules/vmseries | 



### Required Inputs

Name | Type | Description
--- | --- | ---
[`networks`](#networks) | `any` | A map containing each network setting.
[`vmseries`](#vmseries) | `any` | A map containing each individual vmseries setting.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`project`](#project) | `string` | The project name to deploy the infrastructure in to.
[`name_prefix`](#name_prefix) | `string` | A string to prefix resource namings.
[`vmseries_common`](#vmseries_common) | `map` | A map containing common vmseries setting.

### Outputs

Name |  Description
--- | ---
`vmseries_private_ips` | Private IP addresses of the vmseries instances.
`vmseries_public_ips` | Public IP addresses of the vmseries instances.

### Required Inputs details

#### networks

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


Type: any

<sup>[back to list](#modules-required-inputs)</sup>

#### vmseries

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



Type: any

<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### project

The project name to deploy the infrastructure in to.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### name_prefix

A string to prefix resource namings

Type: string

Default value: ``

<sup>[back to list](#modules-optional-inputs)</sup>

#### vmseries_common

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


Type: map

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>
