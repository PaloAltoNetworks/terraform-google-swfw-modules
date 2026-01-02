---
show_in_hub: false
---
# Common Option

The common firewall option leverages a single set of VM-Series firewalls. The sole set of firewalls operates as a shared resource and may present scale limitations with all traffic flowing through a single set of firewalls due to the performance degradation that occurs when traffic crosses virtual routers. This option is suitable for proof-of-concepts and smaller scale deployments because the number of firewalls is low. However, the technical integration complexity is high.

![VM-Series-Multi-NIC-Common-Firewall-Option](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/assets/2110772/017aad21-46c8-4030-853a-f32096da754c)

The scope of this code is to deploy an example of the [VM-Series Common Firewall Option](https://www.paloaltonetworks.com/apps/pan/public/downloadResource?pagePath=/content/pan/en_US/resources/guides/gcp-architecture-guide#Design%20Model) but with a slight modification in the architecture - the VM-Series is directly connected to the spoke VPCs. There are some advantages to this architecture from a routing perspective but there is also a limitation related to the [maximum number of NICs on the VM-Series](https://cloud.google.com/vpc/docs/create-use-multiple-interfaces#max-interfaces) within GCP.

The example makes use of VM-Series full [bootstrap process](https://docs.paloaltonetworks.com/vm-series/10-2/vm-series-deployment/bootstrap-the-vm-series-firewall/bootstrap-the-vm-series-firewall-on-google) using XML templates to properly parametrize the initial Day 0 configuration.

With default variable values the topology consists of :
 - 4 VPC networks :
   - Management VPC
   - Untrust (outside) VPC
   - Spoke-1 (Trust 1) VPC
   - Spoke-2 (Trust 2) VPC
 - 2 VM-Series firewalls
 - 2 Linux Ubuntu VMs (inside Spoke VPCs - for testing purposes)
 - two internal network loadbalancers (for outbound/east-west traffic) - one per spoke VPC
 - one external regional network loadbalancer (for inbound traffic)

## Prerequisites

The following steps should be followed before deploying the Terraform code presented here.

1. Prepare [VM-Series licenses](https://support.paloaltonetworks.com/)
2. Configure the terraform [google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication-configuration)

## Usage

1. Access Google Cloud Shell or any other environment that has access to your GCP project

2. Clone the repository:

```
git clone https://github.com/PaloAltoNetworks/terraform-google-swfw-modules
cd terraform-google-swfw-modules/examples/multi_nic_common
```

3. Copy the `example.tfvars` to `terraform.tfvars`.

`project`, `ssh_keys` and `source_ranges` should be modified for successful deployment and access to the instance.

There are also a few variables that have some default values but which should also be changed as per deployment requirements

 - `region`
 - `vmseries.<fw-name>.bootstrap_options`
 - `linux_vms.<vm-name>.linux_disk_size`

1. Apply the terraform code:

```
terraform init
terraform apply
```

4. Check the output plan and confirm the apply.

5. Check the successful application and outputs of the resulting infrastructure:

```
Apply complete! Resources: 77 added, 0 changed, 0 destroyed. (Number of resources can vary based on how many instances you push through tfvars)

Outputs:

lbs_external_ips = {
  "external-lb" = {
    "all-ports" = "<EXTERNAL_LB_PUBLIC_IP>"
  }
}
lbs_internal_ips = {
  "internal-lb-spoke1" = "10.10.12.5"
  "internal-lb-spoke2" = "10.10.13.5"
}
linux_vm_ips = {
  "spoke1-vm" = "192.168.1.2"
  "spoke2-vm" = "192.168.2.2"
}
vmseries_private_ips = {
  "fw-vmseries-01" = {
    "0" = "10.10.11.2"
    "1" = "10.10.10.2"
    "2" = "10.10.12.2"
    "3" = "10.10.13.2"
  }
  "fw-vmseries-02" = {
    "0" = "10.10.11.3"
    "1" = "10.10.10.3"
    "2" = "10.10.12.3"
    "3" = "10.10.13.3"
  }
}
vmseries_public_ips = {
  "fw-vmseries-01" = {
    "0" = "<UNTRUST_PUBLIC_IP>"
    "1" = "<MGMT_PUBLIC_IP>"
  }
  "fw-vmseries-02" = {
    "0" = "<UNTRUST_PUBLIC_IP>"
    "1" = "<MGMT_PUBLIC_IP>"
  }
}

```

## Post build

Connect to the VM-Series instance(s) via SSH using your associated private key and check if the bootstrap process if finished successfuly and then set a password :
  - Please allow for up to 10-15 minutes for the bootstrap process to finish
  - The key output you should check for is "Auto-commit Successful"

```
ssh admin@x.x.x.x -i /PATH/TO/YOUR/KEY/id_rsa
Welcome admin.
admin@PA-VM> show system bootstrap status

Bootstrap Phase               Status         Details
===============               ======         =======
Media Detection               Success        Media detected successfully
Media Sanity Check            Success        Media sanity check successful
Parsing of Initial Config     Successful     
Auto-commit                   Successful

admin@PA-VM> configure
Entering configuration mode
[edit]                                                                                                                                                                                  
admin@PA-VM# set mgt-config users admin password
Enter password   :
Confirm password :

[edit]                                                                                                                                                                                  
admin@PA-VM# commit
Configuration committed successfully
```

## Check access via web UI

Use a web browser to access `https://<MGMT_PUBLIC_IP>` and login with admin and your previously configured password.

## Change the public Loopback public IP Address

For the VM-Series that are backend instance group members of the public-facing loadbalancer - go to Network -> Interfaces -> Loopback and change the value of `1.1.1.1` with the value from the `EXTERNAL_LB_PUBLIC_IP` from the terraform outputs.

## Check traffic from spoke VMs

The firewalls are bootstrapped with a generic `allow any` policy just for demo purposes along with an outboud SNAT policy to allow Inernet access from spoke VMs.

SSH to one of the spoke VMs using GCP IAP and gcloud command and test connectivity :

```
gcloud compute ssh spoke1-vm
No zone specified. Using zone [us-east1-b] for instance: [spoke1-vm].
External IP address was not found; defaulting to using IAP tunneling.
WARNING:

To increase the performance of the tunnel, consider installing NumPy. For instructions,
please see https://cloud.google.com/iap/docs/using-tcp-forwarding#increasing_the_tcp_upload_bandwidth

<USERNAME>@spoke1-vm:~$ping 8.8.8.8
<USERNAME>@spoke1-vm:~$ping 192.168.2.2
```

## Reference

### Requirements

- `terraform`, version: >= 1.3, < 2.0

### Providers

- `local`
- `google`

### Modules
Name | Version | Source | Description
--- | --- | --- | ---
`iam_service_account` | - | ../../modules/iam_service_account | 
`bootstrap` | - | ../../modules/bootstrap | 
`vpc` | - | ../../modules/vpc | 
`vpc_peering` | - | ../../modules/vpc-peering | 
`vmseries` | - | ../../modules/vmseries | 
`lb_internal` | - | ../../modules/lb_internal | 
`lb_external` | - | ../../modules/lb_external | 

### Resources

- `compute_instance` (managed)
- `compute_route` (managed)
- `file` (managed)
- `sensitive_file` (managed)
- `compute_image` (data)

### Required Inputs

Name | Type | Description
--- | --- | ---

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`project`](#project) | `string` | The project name to deploy the infrastructure in to.
[`region`](#region) | `string` | The region into which to deploy the infrastructure in to.
[`name_prefix`](#name_prefix) | `string` | A string to prefix resource namings.
[`service_accounts`](#service_accounts) | `map` | A map containing each service account setting.
[`bootstrap_buckets`](#bootstrap_buckets) | `map` | A map containing each bootstrap bucket setting.
[`networks`](#networks) | `any` | A map containing each network setting.
[`vpc_peerings`](#vpc_peerings) | `map` | A map containing each VPC peering setting.
[`routes`](#routes) | `map` | A map containing each route setting.
[`vmseries_common`](#vmseries_common) | `object` | A map containing common vmseries settings.
[`vmseries`](#vmseries) | `map` | A map containing each individual vmseries setting.
[`lbs_internal`](#lbs_internal) | `map` | A map containing each internal loadbalancer setting.
[`lbs_external`](#lbs_external) | `map` | A map containing each external loadbalancer setting.
[`linux_vms`](#linux_vms) | `map` | A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.

### Outputs

Name |  Description
--- | ---
`vmseries_private_ips` | Private IP addresses of the vmseries instances.
`vmseries_public_ips` | Public IP addresses of the vmseries instances.
`lbs_internal_ips` | Private IP addresses of internal network loadbalancers.
`lbs_external_ips` | Public IP addresses of external network loadbalancers.
`linux_vm_ips` | Private IP addresses of Linux VMs.

### Required Inputs details

### Optional Inputs details

#### project

The project name to deploy the infrastructure in to.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### region

The region into which to deploy the infrastructure in to.

Type: string

Default value: `us-central1`

<sup>[back to list](#modules-optional-inputs)</sup>

#### name_prefix

A string to prefix resource namings.

Type: string

Default value: `example-`

<sup>[back to list](#modules-optional-inputs)</sup>

#### service_accounts

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



Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### bootstrap_buckets

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



Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### networks

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
        source_ranges    = ["10.10.10.0/24"]
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


Type: any

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vpc_peerings

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


Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### routes

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


Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vmseries_common

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


Type: 

```hcl
object({
    ssh_keys            = optional(string)
    vmseries_image      = optional(string)
    machine_type        = optional(string)
    min_cpu_platform    = optional(string)
    tags                = optional(list(string))
    service_account_key = optional(string)
    scopes              = optional(list(string))
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
  })
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vmseries

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
      "https://www.googleapis.com/auth/monitoring",
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



Type: 

```hcl
map(object({
    name = string
    zone = string
    network_interfaces = optional(list(object({
      vpc_network_key  = string
      subnetwork_key   = string
      private_ip       = string
      create_public_ip = optional(bool, false)
      public_ip        = optional(string)
      public_ip_region = optional(string)
    })))
    ssh_keys            = optional(string)
    vmseries_image      = optional(string)
    machine_type        = optional(string)
    min_cpu_platform    = optional(string)
    tags                = optional(list(string))
    service_account_key = optional(string)
    service_account     = optional(string)
    scopes              = optional(list(string))
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
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### lbs_internal

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


Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### lbs_external

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


Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### linux_vms

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


Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3, < 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bootstrap"></a> [bootstrap](#module\_bootstrap) | ../../modules/bootstrap | n/a |
| <a name="module_iam_service_account"></a> [iam\_service\_account](#module\_iam\_service\_account) | ../../modules/iam_service_account | n/a |
| <a name="module_lb_external"></a> [lb\_external](#module\_lb\_external) | ../../modules/lb_external | n/a |
| <a name="module_lb_internal"></a> [lb\_internal](#module\_lb\_internal) | ../../modules/lb_internal | n/a |
| <a name="module_vmseries"></a> [vmseries](#module\_vmseries) | ../../modules/vmseries | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../modules/vpc | n/a |
| <a name="module_vpc_peering"></a> [vpc\_peering](#module\_vpc\_peering) | ../../modules/vpc-peering | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_instance.linux_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_route.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [local_file.bootstrap_xml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_sensitive_file.init_cfg](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [google_compute_image.my_image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bootstrap_buckets"></a> [bootstrap\_buckets](#input\_bootstrap\_buckets) | A map containing each bootstrap bucket setting.<br/><br/>Example of variable deployment:<pre>bootstrap_buckets = {<br/>  vmseries-bootstrap-bucket-01 = {<br/>    bucket_name_prefix  = "bucket-01-"<br/>    location            = "us"<br/>    service_account_key = "sa-vmseries-01"<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/bootstrap#Inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_lbs_external"></a> [lbs\_external](#input\_lbs\_external) | A map containing each external loadbalancer setting.<br/><br/>Example of variable deployment :<pre>lbs_external = {<br/>  "external-lb" = {<br/>    name     = "external-lb"<br/>    backends = ["fw-vmseries-01", "fw-vmseries-02"]<br/>    rules = {<br/>      "all-ports" = {<br/>        ip_protocol = "L3_DEFAULT"<br/>      }<br/>    }<br/>    http_health_check_port         = "80"<br/>    http_health_check_request_path = "/php/login.php"<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_external#inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_lbs_internal"></a> [lbs\_internal](#input\_lbs\_internal) | A map containing each internal loadbalancer setting.<br/><br/>Example of variable deployment :<pre>lbs_internal = {<br/>  "internal-lb" = {<br/>    name              = "internal-lb"<br/>    health_check_port = "80"<br/>    backends          = ["fw-vmseries-01", "fw-vmseries-02"]<br/>    ip_address        = "10.10.12.5"<br/>    subnetwork_key    = "fw-trust-sub"<br/>    vpc_network_key   = "fw-trust-vpc"<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_internal#inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_linux_vms"></a> [linux\_vms](#input\_linux\_vms) | A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.<br/><br/>Example of varaible deployment:<pre>linux_vms = {<br/>  spoke1-vm = {<br/>    linux_machine_type = "n2-standard-4"<br/>    zone               = "us-east1-b"<br/>    linux_disk_size    = "50" # Modify this value as per deployment requirements<br/>    vpc_network_key    = "fw-spoke1-vpc"<br/>    subnetwork_key     = "fw-spoke1-sub"<br/>    private_ip         = "192.168.1.2"<br/>    scopes = [<br/>      "https://www.googleapis.com/auth/compute.readonly",<br/>      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br/>      "https://www.googleapis.com/auth/devstorage.read_only",<br/>      "https://www.googleapis.com/auth/logging.write",<br/>      "https://www.googleapis.com/auth/monitoring",<br/>    ]<br/>    service_account_key = "sa-linux-01"<br/>  }<br/>}</pre> | `map(any)` | `{}` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A string to prefix resource namings. | `string` | `"example-"` | no |
| <a name="input_networks"></a> [networks](#input\_networks) | A map containing each network setting.<br/><br/>Example of variable deployment :<pre>networks = {<br/>  fw-mgmt-vpc = {<br/>    vpc_name = "fw-mgmt-vpc"<br/>    create_network = true<br/>    delete_default_routes_on_create = false<br/>    mtu = "1460"<br/>    routing_mode = "REGIONAL"<br/>    subnetworks = {<br/>      fw-mgmt-sub = {<br/>        name              = "fw-mgmt-sub"<br/>        create_subnetwork = true<br/>        ip_cidr_range     = "10.10.10.0/28"<br/>        region            = "us-east1"<br/>      }<br/>    }<br/>    firewall_rules = {<br/>      allow-mgmt-ingress = {<br/>        name             = "allow-mgmt-ingress"<br/>        source_ranges    = ["10.10.10.0/24"]<br/>        priority         = "1000"<br/>        allowed_protocol = "all"<br/>        allowed_ports    = []<br/>      }<br/>    }<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc#input_networks)<br/><br/>Multiple keys can be added and will be deployed by the code. | `any` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | The project name to deploy the infrastructure in to. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region into which to deploy the infrastructure in to. | `string` | `"us-central1"` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | A map containing each route setting. Note that you can only add routes using a next-hop type of internal load-balance rule.<br/><br/>Example of variable deployment :<pre>routes = {<br/>  "default-route-trust" = {<br/>    name = "fw-default-trust"<br/>    destination_range = "0.0.0.0/0"<br/>    vpc_network_key = "fw-trust-vpc"<br/>    lb_internal_name = "internal-lb"<br/>  }<br/>}</pre>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_service_accounts"></a> [service\_accounts](#input\_service\_accounts) | A map containing each service account setting.<br/><br/>Example of variable deployment :<pre>service_accounts = {<br/>  "sa-vmseries-01" = {<br/>    service_account_id = "sa-vmseries-01"<br/>    display_name       = "VM-Series SA"<br/>    roles = [<br/>      "roles/compute.networkViewer",<br/>      "roles/logging.logWriter",<br/>      "roles/monitoring.metricWriter",<br/>      "roles/monitoring.viewer",<br/>      "roles/viewer"<br/>    ]<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/iam_service_account#Inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_vmseries"></a> [vmseries](#input\_vmseries) | A map containing each individual vmseries setting.<br/><br/>Example of variable deployment :<pre>vmseries = {<br/>  "fw-vmseries-01" = {<br/>    name             = "fw-vmseries-01"<br/>    zone             = "us-east1-b"<br/>    machine_type     = "n2-standard-4"<br/>    min_cpu_platform = "Intel Cascade Lake"<br/>    tags                 = ["vmseries"]<br/>    service_account_key  = "sa-vmseries-01"<br/>    scopes = [<br/>      "https://www.googleapis.com/auth/compute.readonly",<br/>      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br/>      "https://www.googleapis.com/auth/devstorage.read_only",<br/>      "https://www.googleapis.com/auth/logging.write",<br/>      "https://www.googleapis.com/auth/monitoring",<br/>    ]<br/>    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"<br/>    bootstrap_options = {<br/>      panorama-server = "1.1.1.1"<br/>      dns-primary     = "8.8.8.8"<br/>      dns-secondary   = "8.8.4.4"<br/>    }<br/>    bootstrap_template_map = {<br/>      trust_gcp_router_ip   = "10.10.12.1"<br/>      untrust_gcp_router_ip = "10.10.11.1"<br/>      private_network_cidr  = "192.168.0.0/16"<br/>      untrust_loopback_ip   = "1.1.1.1/32" #This is placeholder IP - you must replace it on the vmseries config with the LB public IP address after the infrastructure is deployed<br/>      trust_loopback_ip     = "10.10.12.5/32"<br/>    }<br/>    named_ports = [<br/>      {<br/>        name = "http"<br/>        port = 80<br/>      },<br/>      {<br/>        name = "https"<br/>        port = 443<br/>      }<br/>    ]<br/>    network_interfaces = [<br/>      {<br/>        vpc_network_key  = "fw-untrust-vpc"<br/>        subnetwork_key       = "fw-untrust-sub"<br/>        private_ip       = "10.10.11.2"<br/>        create_public_ip = true<br/>      },<br/>      {<br/>        vpc_network_key  = "fw-mgmt-vpc"<br/>        subnetwork_key       = "fw-mgmt-sub"<br/>        private_ip       = "10.10.10.2"<br/>        create_public_ip = true<br/>      },<br/>      {<br/>        vpc_network_key = "fw-trust-vpc"<br/>        subnetwork_key = "fw-trust-sub"<br/>        private_ip = "10.10.12.2"<br/>      },<br/>    ]<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vmseries#inputs)<br/><br/>The bootstrap\_template\_map contains variables that will be applied to the bootstrap template. Each firewall Day 0 bootstrap will be parametrised based on these inputs.<br/>Multiple keys can be added and will be deployed by the code. | <pre>map(object({<br/>    name = string<br/>    zone = string<br/>    network_interfaces = optional(list(object({<br/>      vpc_network_key  = string<br/>      subnetwork_key   = string<br/>      private_ip       = string<br/>      create_public_ip = optional(bool, false)<br/>      public_ip        = optional(string)<br/>      public_ip_region = optional(string)<br/>    })))<br/>    ssh_keys            = optional(string)<br/>    vmseries_image      = optional(string)<br/>    machine_type        = optional(string)<br/>    min_cpu_platform    = optional(string)<br/>    tags                = optional(list(string))<br/>    service_account_key = optional(string)<br/>    service_account     = optional(string)<br/>    scopes              = optional(list(string))<br/>    bootstrap_options = optional(object({<br/>      type                                  = optional(string)<br/>      mgmt-interface-swap                   = optional(string)<br/>      plugin-op-commands                    = optional(string)<br/>      panorama-server                       = optional(string)<br/>      auth-key                              = optional(string)<br/>      dgname                                = optional(string)<br/>      tplname                               = optional(string)<br/>      dhcp-send-hostname                    = optional(string)<br/>      dhcp-send-client-id                   = optional(string)<br/>      dhcp-accept-server-hostname           = optional(string)<br/>      dhcp-accept-server-domain             = optional(string)<br/>      authcodes                             = optional(string)<br/>      vm-series-auto-registration-pin-id    = optional(string)<br/>      vm-series-auto-registration-pin-value = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_vmseries_common"></a> [vmseries\_common](#input\_vmseries\_common) | A map containing common vmseries settings.<br/><br/>Example of variable deployment :<pre>vmseries_common = {<br/>  ssh_keys            = "admin:AAAABBBB..."<br/>  vmseries_image      = "vmseries-flex-byol-10210h9"<br/>  machine_type        = "n2-standard-4"<br/>  min_cpu_platform    = "Intel Cascade Lake"<br/>  service_account_key = "sa-vmseries-01"<br/>  bootstrap_options = {<br/>    type                = "dhcp-client"<br/>    mgmt-interface-swap = "enable"<br/>  }<br/>}</pre>Majority of settings can be moved between this common and individual instance (ie. `var.vmseries`) variables. If values for the same item are specified in both of them, one from the latter will take precedence. | <pre>object({<br/>    ssh_keys            = optional(string)<br/>    vmseries_image      = optional(string)<br/>    machine_type        = optional(string)<br/>    min_cpu_platform    = optional(string)<br/>    tags                = optional(list(string))<br/>    service_account_key = optional(string)<br/>    scopes              = optional(list(string))<br/>    bootstrap_options = optional(object({<br/>      type                                  = optional(string)<br/>      mgmt-interface-swap                   = optional(string)<br/>      plugin-op-commands                    = optional(string)<br/>      panorama-server                       = optional(string)<br/>      auth-key                              = optional(string)<br/>      dgname                                = optional(string)<br/>      tplname                               = optional(string)<br/>      dhcp-send-hostname                    = optional(string)<br/>      dhcp-send-client-id                   = optional(string)<br/>      dhcp-accept-server-hostname           = optional(string)<br/>      dhcp-accept-server-domain             = optional(string)<br/>      authcodes                             = optional(string)<br/>      vm-series-auto-registration-pin-id    = optional(string)<br/>      vm-series-auto-registration-pin-value = optional(string)<br/>    }))<br/>  })</pre> | `{}` | no |
| <a name="input_vpc_peerings"></a> [vpc\_peerings](#input\_vpc\_peerings) | A map containing each VPC peering setting.<br/><br/>Example of variable deployment :<pre>vpc_peerings = {<br/>  "trust-to-spoke1" = {<br/>    local_network_key = "fw-trust-vpc"<br/>    peer_network_key  = "fw-spoke1-vpc"<br/><br/>    local_export_custom_routes                = true<br/>    local_import_custom_routes                = true<br/>    local_export_subnet_routes_with_public_ip = true<br/>    local_import_subnet_routes_with_public_ip = true<br/><br/>    peer_export_custom_routes                = true<br/>    peer_import_custom_routes                = true<br/>    peer_export_subnet_routes_with_public_ip = true<br/>    peer_import_subnet_routes_with_public_ip = true<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc-peering#inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lbs_external_ips"></a> [lbs\_external\_ips](#output\_lbs\_external\_ips) | Public IP addresses of external network loadbalancers. |
| <a name="output_lbs_internal_ips"></a> [lbs\_internal\_ips](#output\_lbs\_internal\_ips) | Private IP addresses of internal network loadbalancers. |
| <a name="output_linux_vm_ips"></a> [linux\_vm\_ips](#output\_linux\_vm\_ips) | Private IP addresses of Linux VMs. |
| <a name="output_vmseries_private_ips"></a> [vmseries\_private\_ips](#output\_vmseries\_private\_ips) | Private IP addresses of the vmseries instances. |
| <a name="output_vmseries_public_ips"></a> [vmseries\_public\_ips](#output\_vmseries\_public\_ips) | Public IP addresses of the vmseries instances. |
<!-- END_TF_DOCS -->