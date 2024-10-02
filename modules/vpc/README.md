# VPC Network Module for GCP

A Terraform module for deploying a VPC and associated subnetworks and firewall rules in GCP.

One advantage of this module over the [terraform-google-network](https://github.com/terraform-google-modules/terraform-google-network/tree/master) module is that this module lets you use existing VPC networks and subnetworks to support brownfield deployments. 

# IPv4/IPv6 Dual Stack Usage Example

```
locals {
  project     = "<project_id>"
  name_prefix = "test-ipv6-"
  networks = {
    inside-vpc = {
      vpc_name                        = "inside-vpc"
      create_network                  = true
      delete_default_routes_on_create = true
      mtu                             = "1460"
      routing_mode                    = "REGIONAL"
      enable_ula_internal_ipv6        = true
      subnetworks = {
        inside-snet = {
          subnetwork_name   = "inside-vpc-snet"
          create_subnetwork = true
          ip_cidr_range     = "10.10.10.0/24"
          region            = "us-east1"
          stack_type        = "IPV4_IPV6"
          ipv6_access_type  = "INTERNAL"
        }
      }
      firewall_rules = {
        allow-inside-ingress4 = {
          name             = "allow-inside-ingress4"
          source_ranges    = ["35.191.0.0/16", "130.211.0.0/22", "10.0.0.0/8"]
          priority         = "1000"
          allowed_protocol = "all"
          allowed_ports    = []
        }
        allow-inside-ingress6 = {
          name             = "allow-inside-ingress6"
          source_ranges    = ["::/0"]
          priority         = "1000"
          allowed_protocol = "all"
          allowed_ports    = []
        }
      }
    }
    untrust-vpc = {
      vpc_name       = "untrust-vpc"
      create_network = true
      subnetworks = {
        untrust-snet = {
          subnetwork_name   = "untrust-vpc-snet"
          create_subnetwork = true
          ip_cidr_range     = "10.10.20.0/24"
          region            = "us-east1"
          stack_type        = "IPV4_IPV6"
          ipv6_access_type  = "EXTERNAL"
        }
      }
      firewall_rules = {
        allow-untrust-ingress6 = {
          name             = "allow-untrust-ingress6"
          source_ranges    = ["::/0"]
          priority         = "1000"
          allowed_protocol = "all"
          allowed_ports    = []
        }
      }
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  for_each = local.networks

  project_id                      = local.project
  name                            = "${local.name_prefix}${each.value.vpc_name}"
  create_network                  = each.value.create_network
  delete_default_routes_on_create = try(each.value.delete_default_routes_on_create, false)
  mtu                             = try(each.value.mtu, 1460)
  routing_mode                    = try(each.value.routing_mode, "REGIONAL")
  enable_ula_internal_ipv6        = try(each.value.enable_ula_internal_ipv6, false)
  internal_ipv6_range             = try(each.value.internal_ipv6_range, "")
  subnetworks = { for k, v in each.value.subnetworks : k => merge(v, {
    name = "${local.name_prefix}${v.subnetwork_name}"
    })
  }
  firewall_rules = try({ for k, v in each.value.firewall_rules : k => merge(v, {
    name = "${local.name_prefix}${v.name}"
    })
  }, {})
}
```

## Reference
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3, < 2.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.54 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 4.54 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [google_compute_firewall.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_network"></a> [create\_network](#input\_create\_network) | A flag to indicate the creation or import of a VPC network.<br>Setting this to `true` will create a new network managed by Terraform.<br>Setting this to `false` will try to read the existing network identified by `name` and `project` variables. | `bool` | `true` | no |
| <a name="input_delete_default_routes_on_create"></a> [delete\_default\_routes\_on\_create](#input\_delete\_default\_routes\_on\_create) | A flag to indicate the deletion of the default routes at VPC creation.<br>Setting this to `true` the default route `0.0.0.0/0` will be deleted upon network creation.<br>Setting this to `false` the default route `0.0.0.0/0` will be not be deleted upon network creation. | `bool` | `false` | no |
| <a name="input_enable_ula_internal_ipv6"></a> [enable\_ula\_internal\_ipv6](#input\_enable\_ula\_internal\_ipv6) | Enable ULA internal IPv6 on this network.<br>Enabling this feature will assign a /48 subnet from Google defined ULA prefix fd20::/20. | `bool` | `false` | no |
| <a name="input_firewall_rules"></a> [firewall\_rules](#input\_firewall\_rules) | A map containing each firewall rule configuration.<br>Action of the firewall rule is always `allow`.<br>The only possible direction of the firewall rule is `INGRESS`.<br><br>List of available attributes of each firewall rule entry:<br>- `name` : Name of the firewall rule.<br>- `source_ranges` : (Optional) A list of strings containing the source IP ranges to be allowed on the firewall rule.<br>- `source_tags` : (Optional) A list of strings containing the source network tags to be allowed on the firewall rule.<br>- `source_service_accounts` : (Optional) A list of strings containg the source servce accounts to be allowed on the firewall rule.<br>- `target_service_accounts` : (Optional) A list of strings containing the service accounts for which the firewall rule applies to.<br>- `target_tags` : (Optional) A list of strings containing the network tags for which the firewall rule applies to. <br>- `allowed_protocol` : The protocol type to match in the firewall rule. Possible values are: `tcp`, `udp`, `icmp`, `esp`, `ah`, `sctp`, `ipip`, `all`.<br>- `ports` : A list of strings containing TCP or UDP port numbers to match in the firewall rule. This type of setting can only be configured if allowing TCP and UDP as protocols.<br>- `priority` : (Optional) A priority value for the firewall rule. The lower the number - the more preferred the rule is.<br>- `log_metadata` : (Optional) This field denotes whether to include or exclude metadata for firewall logs. Possible values are: `EXCLUDE_ALL_METADATA`, `INCLUDE_ALL_METADATA`.<br><br>Example :<pre>firewall_rules = {<br>  firewall-rule-v4 = {<br>    name             = "allow-range-ipv4"<br>    source_ranges    = ["10.10.10.0/24", "1.1.1.0/24"]<br>    priority         = "2000"<br>    target_tags      = ["vmseries-firewalls"]<br>    allowed_protocol = "TCP"<br>    allowed_ports    = ["443", "22"]<br>  }<br>  firewall-rule-v6 = {<br>    name             = "allow-range-ipv6"<br>    source_ranges    = ["::/0"]<br>    priority         = "1000"<br>    allowed_protocol = "all"<br>    allowed_ports    = []<br>  }<br>}</pre> | <pre>map(object({<br>    name                    = string<br>    source_ranges           = optional(list(string))<br>    source_tags             = optional(list(string))<br>    source_service_accounts = optional(list(string))<br>    allowed_protocol        = string<br>    allowed_ports           = list(string)<br>    priority                = optional(string)<br>    target_service_accounts = optional(list(string))<br>    target_tags             = optional(list(string))<br>    log_metadata            = optional(string)<br>  }))</pre> | `{}` | no |
| <a name="input_internal_ipv6_range"></a> [internal\_ipv6\_range](#input\_internal\_ipv6\_range) | When enabling ULA internal IPv6 you can optionally specify the /48 range. <br>The input must be a valid /48 ULA IPv6 address within the range fd20::/20. <br>Operation will fail if the speficied /48 is already in use by another resource. | `string` | `""` | no |
| <a name="input_mtu"></a> [mtu](#input\_mtu) | MTU value for VPC Network. Acceptable values are between 1300 and 8896. | `number` | `1460` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the created or already existing VPC Network. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project in which to create or look for VPCs and subnets | `string` | `null` | no |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | Type of network-wide routing mode to use. Possible types are: REGIONAL and GLOBAL.<br>REGIONAL routing mode will set the cloud routers to only advertise subnetworks within the same region as the router.<br>GLOBAL routing mode will set the cloud routers to advertise all the subnetworks that belong to this network. | `string` | `"REGIONAL"` | no |
| <a name="input_subnetworks"></a> [subnetworks](#input\_subnetworks) | A map containing subnetworks configuration. Subnets can belong to different regions.<br>List of available attributes of each subnetwork entry:<br>- `name` : Name of the subnetwork.<br>- `create_subnetwork` : Boolean value to control the creation or reading of the subnetwork. If set to `true` - this will create the subnetwork. If set to `false` - this will read a subnet with provided information.<br>- `ip_cidr_range` : A string that contains the subnetwork to create. Only IPv4 format is supported.<br>- `region` : Region where to configure or import the subnet.<br>- `stack_type` : IP stack type. IPV4\_ONLY (default) and IPV4\_IPV6 are supported.<br>- `ipv6_access_type` : The access type of IPv6 address. It's immutable and can only be specified during creation or the first time the subnet is updated into IPV4\_IPV6 dual stack. Possible values are: EXTERNAL, INTERNAL.<br>- `log_config` : (Optional) A map containing the logging configuration for the subnetwork.<br>  - `aggregation_interval` : (Optional) The interval at which logs are aggregated for the subnetwork. Possible values are: `INTERVAL_5_SEC`, `INTERVAL_30_SEC`, `INTERVAL_1_MIN`, `INTERVAL_5_MIN`, `INTERVAL_10_MIN`, `INTERVAL_15_MIN`.<br>  - `flow_sampling` : (Optional) The value of the field must be in [0, 1]. Set the sampling rate of VPC flow logs within the subnetwork where 1.0 means all collected logs are reported and 0.0 means no logs are reported.<br>  - `metadata` : (Optional) Configures whether metadata fields should be added to the reported VPC flow logs. Default value is `INCLUDE_ALL_METADATA`. Possible values are: `EXCLUDE_ALL_METADATA`, `INCLUDE_ALL_METADATA`, `CUSTOM_METADATA`.<br>  - `metadata_fields` : (Optional) List of metadata fields that should be added to reported logs. Can only be specified if VPC flow logs for this subnetwork is enabled and `metadata` is set to `CUSTOM_METADATA`.<br>  - `filter_expr` : (Optional) Export filter used to define which VPC flow logs should be logged, as as CEL expression.<br><br>Example:<pre>subnetworks = {<br>  my-sub = {<br>    name = "my-sub"<br>    create_subnetwork = true<br>    ip_cidr_range = "192.168.0.0/24"<br>    region = "us-east1"<br>  }<br>}</pre> | <pre>map(object({<br>    name              = string<br>    create_subnetwork = optional(bool, true)<br>    ip_cidr_range     = string<br>    region            = string<br>    stack_type        = optional(string)<br>    ipv6_access_type  = optional(string)<br>    log_config = optional(object({<br>      aggregation_interval = optional(string)<br>      flow_sampling        = optional(string)<br>      metadata             = optional(string)<br>      metadata_fields      = optional(list(string))<br>      filter_expr          = optional(string)<br>    }))<br>  }))</pre> | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_network"></a> [network](#output\_network) | Created or read network attributes. |
| <a name="output_subnetworks"></a> [subnetworks](#output\_subnetworks) | Map containing key, value pairs of created or read subnetwork attributes. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
