---
show_in_hub: false
---
# Reference Architecture with Terraform: VM-Series in GCP, Centralized Architecture, Dedicated inbound NGFW with autoscale Option

Palo Alto Networks produces several [validated reference architecture design and deployment documentation guides](https://www.paloaltonetworks.com/resources/reference-architectures), which describe well-architected and tested deployments. When deploying VM-Series in a public cloud, the reference architectures guide users toward the best security outcomes, whilst reducing rollout time and avoiding common integration efforts.
The Terraform code presented here will deploy Palo Alto Networks VM-Series firewalls in GCP based on a centralized design with dedicated inbound VM-Series and autoscaling capabilities for all traffic; for a discussion of other options, please see the design guide from [the reference architecture guides](https://www.paloaltonetworks.com/resources/reference-architectures).

## Detailed Architecture and Design

### Centralized Design

This design uses a VPC Peering. Application functions are distributed across multiple projects that are connected in a logical hub-and-spoke topology. A security project acts as the hub, providing centralized connectivity and control for multiple application projects. You deploy all VM-Series firewalls within the security project. The spoke projects contain the workloads and necessary services to support the application deployment.
This design model integrates multiple methods to interconnect and control your application project VPC networks with resources in the security project. VPC Peering enables the private VPC network in the security project to peer with, and share routing information to, each application project VPC network. Using Shared VPC, the security project administrators create and share VPC network resources from within the security project to the application projects. The application project administrators can select the network resources and deploy the application workloads.

### Dedicated inbound Option with autoscaling

The dedicated inbound firewall option with autoscaling leverages a single set autoscale group of VM-Series firewalls. Compared to the standard dedicated inbound firewall option - the autoscaling solved the issue of resource bottleneck given by a single set of firewalls, being able to scale horizontally based on configurable metrics.

![VM-Series-Dedicated-Firewall-Option-With-Autoscaling](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/assets/2110772/3e61f010-4c79-4654-98b3-44c3955804a4)

The scope of this code is to deploy an example of the [VM-Series Dedicated Inbound Firewall Option](https://www.paloaltonetworks.com/apps/pan/public/downloadResource?pagePath=/content/pan/en_US/resources/guides/gcp-architecture-guide#Design%20Model) architecture within a GCP project, but using an autoscaling group of instances instead of a single pair of firewall.

The example makes use of VM-Series basic [bootstrap process](https://docs.paloaltonetworks.com/vm-series/10-2/vm-series-deployment/bootstrap-the-vm-series-firewall/bootstrap-the-vm-series-firewall-on-google) using metadata information to pass bootstrap parameters to the autoscale instances.

With default variable values the topology consists of :
 - 5 VPC networks :
   - Management VPC
   - Untrust (outside) VPC
   - Trust (inside/security) VPC
   - Spoke-1 VPC
   - Spoke-2 VPC
 - 2 Autoscaling Group
 - 2 Linux Ubuntu VMs (inside Spoke VPCs - for testing purposes)
 - one internal network loadbalancer (for outbound/east-west traffic)
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
cd terraform-google-swfw-modules/examples/vpc_peering_dedicated_with_autoscale
```

3. Copy the `example.tfvars` to `terraform.tfvars`.

`project`, `ssh_keys` and management network `source_ranges` firewall rule should be modified for successful deployment and access to the instance.

There are also a few variables that have some default values but which should also be changed as per deployment requirements

 - `region`
 - `autoscale_common.bootstrap_options`
 - `autoscale.<autoscale-name>.bootstrap_options`
 - `linux_vms.<vm-name>.linux_disk_size`

1. Apply the terraform code:

```
terraform init
terraform apply
```

4. Check the output plan and confirm the apply.

5. Check the successful application and outputs of the resulting infrastructure:

```
Apply complete! Resources: 55 added, 0 changed, 0 destroyed.

Outputs:

lbs_external_ips = {
  "external-lb" = {
    "all-portsss" = "<EXTERNAL_LB_PUBLIC_IP>"
  }
}
lbs_internal_ips = {
  "internal-lb" = "10.10.12.4"
}
linux_vm_ips = {
  "spoke1-vm" = "192.168.1.2"
  "spoke2-vm" = "192.168.2.2"
}
pubsub_subscription_id = {
  "fw-autoscale-inbound" = "projects/gcp-gcs-pso/subscriptions/hgu-asi-ref-fw-autoscale-inbound-mig"
  "fw-autoscale-obew" = "projects/gcp-gcs-pso/subscriptions/hgu-asi-ref-fw-autoscale-obew-mig"
}
pubsub_topic_id = {
  "fw-autoscale-inbound" = "projects/gcp-gcs-pso/topics/hgu-asi-ref-fw-autoscale-inbound-mig"
  "fw-autoscale-obew" = "projects/gcp-gcs-pso/topics/hgu-asi-ref-fw-autoscale-obew-mig"
}

```

## Post build

Usually autoscale groups are managed by Panorama - but they can also be accessed directly via the public/private IP address like any other VM within GCP.

Connect to the VM-Series instance(s) via SSH using your associated private key and set a password :

```
ssh admin@x.x.x.x -i /PATH/TO/YOUR/KEY/id_rsa
Welcome admin.

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

Use a web browser to access `https://<MGMT_PUBLIC_IP>` (these can be obtained via the GCP console/API) and login with admin and your previously configured password.

## Change the public Loopback public IP Address

For the VM-Series that are backend instance group members of the public-facing loadbalancer - go to Network -> Interfaces -> Loopback and change the value of `1.1.1.1` with the value from the `EXTERNAL_LB_PUBLIC_IP` from the terraform outputs.

## Check traffic from spoke VMs

After you do some basic configuration on the autoscaling group vmseries - you can try to check connectivity via the spoke VMs (the following tests presume that the autoscale group has been configured to process east - west traffic).

SSH to one of the spoke VMs using GCP IAP and gcloud command and test connectivity :

```
$ gcloud compute ssh spoke1-vm
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

- `google`

### Modules
Name | Version | Source | Description
--- | --- | --- | ---
`iam_service_account` | - | ../../modules/iam_service_account | 
`vpc` | - | ../../modules/vpc | 
`vpc_peering` | - | ../../modules/vpc-peering | 
`autoscale` | - | ../../modules/autoscale/ | 
`lb_internal` | - | ../../modules/lb_internal | 
`lb_external` | - | ../../modules/lb_external | 

### Resources

- `compute_instance` (managed)
- `compute_route` (managed)
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
[`networks`](#networks) | `any` | A map containing each network setting.
[`vpc_peerings`](#vpc_peerings) | `map` | A map containing each VPC peering setting.
[`routes`](#routes) | `map` | A map containing each route setting.
[`autoscale_regional_mig`](#autoscale_regional_mig) | `bool` | Sets the managed instance group type to either a regional (if `true`) or a zonal (if `false`).
[`autoscale_common`](#autoscale_common) | `object` | A map containing common vmseries autoscale settings.
[`autoscale`](#autoscale) | `map` | A map containing each vmseries autoscale setting.
[`lbs_internal`](#lbs_internal) | `map` | A map containing each internal loadbalancer setting.
[`lbs_external`](#lbs_external) | `map` | A map containing each external loadbalancer setting.
[`linux_vms`](#linux_vms) | `map` | A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.

### Outputs

Name |  Description
--- | ---
`pubsub_topic_id` | The resource ID of the Pub/Sub Topic.
`pubsub_subscription_id` | The resource ID of the Pub/Sub Subscription.
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

#### autoscale_regional_mig

Sets the managed instance group type to either a regional (if `true`) or a zonal (if `false`).
For more information please see [About regional MIGs](https://cloud.google.com/compute/docs/instance-groups/regional-migs#why_choose_regional_managed_instance_groups).


Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### autoscale_common

A map containing common vmseries autoscale settings.

Example of variable deployment :

```
autoscale_common = {
  image            = "vmseries-flex-byol-1114h7"
  machine_type     = "n2-standard-4"
  min_cpu_platform = "Intel Cascade Lake"
  disk_type        = "pd-ssd"
  scopes = [
    "https://www.googleapis.com/auth/compute.readonly",
    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
  ]
  tags               = ["vmseries-autoscale"]
  update_policy_type = "OPPORTUNISTIC"
  cooldown_period    = 480
  bootstrap_options  = [
    panorama_server  = "1.1.1.1"
  ]
}
``` 


Type: 

```hcl
object({
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
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### autoscale

A map containing each vmseries autoscale setting.
Zonal or regional managed instance group type is controlled from the `autoscale_regional_mig` variable for all autoscale instances.

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


Type: 

```hcl
map(object({
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
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### lbs_internal

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

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_autoscale"></a> [autoscale](#module\_autoscale) | ../../modules/autoscale/ | n/a |
| <a name="module_iam_service_account"></a> [iam\_service\_account](#module\_iam\_service\_account) | ../../modules/iam_service_account | n/a |
| <a name="module_lb_external"></a> [lb\_external](#module\_lb\_external) | ../../modules/lb_external | n/a |
| <a name="module_lb_internal"></a> [lb\_internal](#module\_lb\_internal) | ../../modules/lb_internal | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../modules/vpc | n/a |
| <a name="module_vpc_peering"></a> [vpc\_peering](#module\_vpc\_peering) | ../../modules/vpc-peering | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_instance.linux_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_route.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_image.my_image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscale"></a> [autoscale](#input\_autoscale) | A map containing each vmseries autoscale setting.<br/>Zonal or regional managed instance group type is controlled from the `autoscale_regional_mig` variable for all autoscale instances.<br/><br/>Example of variable deployment :<pre>autoscale = {<br/>  fw-autoscale-common = {<br/>    name = "fw-autoscale-common"<br/>    zones = {<br/>      zone1 = "us-east4-b"<br/>      zone2 = "us-east4-c"<br/>    }<br/>    named_ports = [<br/>      {<br/>        name = "http"<br/>        port = 80<br/>      },<br/>      {<br/>        name = "https"<br/>        port = 443<br/>      }<br/>    ]<br/>    service_account_key   = "sa-vmseries-01"<br/>    min_vmseries_replicas = 2<br/>    max_vmseries_replicas = 4<br/>    create_pubsub_topic   = true<br/>    autoscaler_metrics = {<br/>      "custom.googleapis.com/VMSeries/panSessionUtilization" = {<br/>        target = 70<br/>      }<br/>      "custom.googleapis.com/VMSeries/panSessionThroughputKbps" = {<br/>        target = 700000<br/>      }<br/>    }<br/>    bootstrap_options = {<br/>      type                        = "dhcp-client"<br/>      dhcp-send-hostname          = "yes"<br/>      dhcp-send-client-id         = "yes"<br/>      dhcp-accept-server-hostname = "yes"<br/>      dhcp-accept-server-domain   = "yes"<br/>      mgmt-interface-swap         = "enable"<br/>      panorama-server             = "1.1.1.1"<br/>      ssh-keys                    = "admin:<your_ssh_key>" # Replace this value with client data<br/>    }<br/>    network_interfaces = [<br/>      {<br/>        vpc_network_key  = "fw-untrust-vpc"<br/>        subnetwork_key   = "fw-untrust-sub"<br/>        create_public_ip = true<br/>      },<br/>      {<br/>        vpc_network_key  = "fw-mgmt-vpc"<br/>        subnetwork_key   = "fw-mgmt-sub"<br/>        create_public_ip = true<br/>      },<br/>      {<br/>        vpc_network_key = "fw-trust-vpc"<br/>        subnetwork_key  = "fw-trust-sub"<br/>      }<br/>    ]<br/>  }<br/>}</pre> | <pre>map(object({<br/>    name                             = string<br/>    zones                            = optional(map(string))<br/>    ssh_keys                         = optional(string)<br/>    image                            = optional(string)<br/>    machine_type                     = optional(string)<br/>    min_cpu_platform                 = optional(string)<br/>    disk_type                        = optional(string)<br/>    tags                             = optional(list(string))<br/>    service_account_key              = optional(string)<br/>    scopes                           = optional(list(string))<br/>    min_vmseries_replicas            = optional(number)<br/>    max_vmseries_replicas            = optional(number)<br/>    update_policy_type               = optional(string)<br/>    cooldown_period                  = optional(number)<br/>    scale_in_control_replicas_fixed  = optional(number)<br/>    scale_in_control_time_window_sec = optional(number)<br/>    autoscaler_metrics = optional(map(object({<br/>      target = optional(string)<br/>      type   = optional(string)<br/>      filter = optional(string)<br/>    })))<br/>    network_interfaces = list(object({<br/>      vpc_network_key  = string<br/>      subnetwork_key   = string<br/>      create_public_ip = optional(bool)<br/>      public_ip        = optional(string)<br/>    }))<br/>    named_ports = optional(list(object({<br/>      name = string<br/>      port = number<br/>    })))<br/>    bootstrap_options = optional(object({<br/>      type                                  = optional(string)<br/>      mgmt-interface-swap                   = optional(string)<br/>      plugin-op-commands                    = optional(string)<br/>      panorama-server                       = optional(string)<br/>      auth-key                              = optional(string)<br/>      dgname                                = optional(string)<br/>      tplname                               = optional(string)<br/>      dhcp-send-hostname                    = optional(string)<br/>      dhcp-send-client-id                   = optional(string)<br/>      dhcp-accept-server-hostname           = optional(string)<br/>      dhcp-accept-server-domain             = optional(string)<br/>      authcodes                             = optional(string)<br/>      vm-series-auto-registration-pin-id    = optional(string)<br/>      vm-series-auto-registration-pin-value = optional(string)<br/>    }))<br/>    create_pubsub_topic = optional(bool)<br/>  }))</pre> | `{}` | no |
| <a name="input_autoscale_common"></a> [autoscale\_common](#input\_autoscale\_common) | A map containing common vmseries autoscale settings.<br/><br/>Example of variable deployment :<pre>autoscale_common = {<br/>  image            = "vmseries-flex-byol-1114h7"<br/>  machine_type     = "n2-standard-4"<br/>  min_cpu_platform = "Intel Cascade Lake"<br/>  disk_type        = "pd-ssd"<br/>  scopes = [<br/>    "https://www.googleapis.com/auth/compute.readonly",<br/>    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br/>    "https://www.googleapis.com/auth/devstorage.read_only",<br/>    "https://www.googleapis.com/auth/logging.write",<br/>    "https://www.googleapis.com/auth/monitoring",<br/>  ]<br/>  tags               = ["vmseries-autoscale"]<br/>  update_policy_type = "OPPORTUNISTIC"<br/>  cooldown_period    = 480<br/>  bootstrap_options  = [<br/>    panorama_server  = "1.1.1.1"<br/>  ]<br/>}</pre> | <pre>object({<br/>    ssh_keys            = optional(string)<br/>    image               = optional(string)<br/>    machine_type        = optional(string)<br/>    min_cpu_platform    = optional(string)<br/>    disk_type           = optional(string)<br/>    tags                = optional(list(string))<br/>    service_account_key = optional(string)<br/>    scopes              = optional(list(string))<br/>    named_ports = optional(list(object({<br/>      name = string<br/>      port = number<br/>    })))<br/>    min_vmseries_replicas            = optional(number)<br/>    max_vmseries_replicas            = optional(number)<br/>    update_policy_type               = optional(string)<br/>    cooldown_period                  = optional(number)<br/>    scale_in_control_replicas_fixed  = optional(number)<br/>    scale_in_control_time_window_sec = optional(number)<br/>    autoscaler_metrics = optional(map(object({<br/>      target = optional(string)<br/>      type   = optional(string)<br/>      filter = optional(string)<br/>    })))<br/>    bootstrap_options = optional(object({<br/>      type                                  = optional(string)<br/>      mgmt-interface-swap                   = optional(string)<br/>      plugin-op-commands                    = optional(string)<br/>      panorama-server                       = optional(string)<br/>      auth-key                              = optional(string)<br/>      dgname                                = optional(string)<br/>      tplname                               = optional(string)<br/>      dhcp-send-hostname                    = optional(string)<br/>      dhcp-send-client-id                   = optional(string)<br/>      dhcp-accept-server-hostname           = optional(string)<br/>      dhcp-accept-server-domain             = optional(string)<br/>      authcodes                             = optional(string)<br/>      vm-series-auto-registration-pin-id    = optional(string)<br/>      vm-series-auto-registration-pin-value = optional(string)<br/>    }))<br/>    create_pubsub_topic = optional(bool)<br/>  })</pre> | `{}` | no |
| <a name="input_autoscale_regional_mig"></a> [autoscale\_regional\_mig](#input\_autoscale\_regional\_mig) | Sets the managed instance group type to either a regional (if `true`) or a zonal (if `false`).<br/>For more information please see [About regional MIGs](https://cloud.google.com/compute/docs/instance-groups/regional-migs#why_choose_regional_managed_instance_groups). | `bool` | `true` | no |
| <a name="input_lbs_external"></a> [lbs\_external](#input\_lbs\_external) | A map containing each external loadbalancer setting.<br/><br/>Example of variable deployment :<pre>lbs_external = {<br/>  "external-lb" = {<br/>    name     = "external-lb"<br/>    backends = ["fw-vmseries-01", "fw-vmseries-02"]<br/>    rules = {<br/>      "all-ports" = {<br/>        ip_protocol = "L3_DEFAULT"<br/>      }<br/>    }<br/>    http_health_check_port         = "80"<br/>    http_health_check_request_path = "/php/login.php"<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_external#inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_lbs_internal"></a> [lbs\_internal](#input\_lbs\_internal) | A map containing each internal loadbalancer setting.<br/>Note : private IP reservation is not by default within the example as it may overlap with autoscale IP allocation.<br/><br/>Example of variable deployment :<pre>lbs_internal = {<br/>  "internal-lb" = {<br/>    name              = "internal-lb"<br/>    health_check_port = "80"<br/>    backends          = ["fw-vmseries-01", "fw-vmseries-02"]<br/>    subnetwork_key    = "fw-trust-sub"<br/>    vpc_network_key   = "fw-trust-vpc"<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_internal#inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_linux_vms"></a> [linux\_vms](#input\_linux\_vms) | A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.<br/><br/>Example of varaible deployment:<pre>linux_vms = {<br/>  spoke1-vm = {<br/>    linux_machine_type = "n2-standard-4"<br/>    zone               = "us-east1-b"<br/>    linux_disk_size    = "50" # Modify this value as per deployment requirements<br/>    vpc_network_key    = "fw-spoke1-vpc"<br/>    subnetwork_key     = "fw-spoke1-sub"<br/>    private_ip         = "192.168.1.2"<br/>    scopes = [<br/>      "https://www.googleapis.com/auth/compute.readonly",<br/>      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br/>      "https://www.googleapis.com/auth/devstorage.read_only",<br/>      "https://www.googleapis.com/auth/logging.write",<br/>      "https://www.googleapis.com/auth/monitoring",<br/>    ]<br/>    service_account_key = "sa-linux-01"<br/>  }<br/>}</pre> | `map(any)` | `{}` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A string to prefix resource namings. | `string` | `"example-"` | no |
| <a name="input_networks"></a> [networks](#input\_networks) | A map containing each network setting.<br/><br/>Example of variable deployment :<pre>networks = {<br/>  fw-mgmt-vpc = {<br/>    vpc_name = "fw-mgmt-vpc"<br/>    create_network = true<br/>    delete_default_routes_on_create = false<br/>    mtu = "1460"<br/>    routing_mode = "REGIONAL"<br/>    subnetworks = {<br/>      fw-mgmt-sub = {<br/>        name = "fw-mgmt-sub"<br/>        create_subnetwork = true<br/>        ip_cidr_range = "10.10.10.0/28"<br/>        region = "us-east1"<br/>      }<br/>    }<br/>    firewall_rules = {<br/>      allow-mgmt-ingress = {<br/>        name = "allow-mgmt-ingress"<br/>        source_ranges = ["10.10.10.0/24"]<br/>        priority = "1000"<br/>        allowed_protocol = "all"<br/>        allowed_ports = []<br/>      }<br/>    }<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc#input_networks)<br/><br/>Multiple keys can be added and will be deployed by the code. | `any` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | The project name to deploy the infrastructure in to. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region into which to deploy the infrastructure in to. | `string` | `"us-central1"` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | A map containing each route setting. Note that you can only add routes using a next-hop type of internal load-balance rule.<br/><br/>Example of variable deployment :<pre>routes = {<br/>  "default-route-trust" = {<br/>    name = "fw-default-trust"<br/>    destination_range = "0.0.0.0/0"<br/>    vpc_network_key = "fw-trust-vpc"<br/>    lb_internal_name = "internal-lb"<br/>  }<br/>}</pre>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_service_accounts"></a> [service\_accounts](#input\_service\_accounts) | A map containing each service account setting.<br/><br/>Example of variable deployment :<pre>service_accounts = {<br/>  "sa-vmseries-01" = {<br/>    service_account_id = "sa-vmseries-01"<br/>    display_name       = "VM-Series SA"<br/>    roles = [<br/>      "roles/compute.networkViewer",<br/>      "roles/logging.logWriter",<br/>      "roles/monitoring.metricWriter",<br/>      "roles/monitoring.viewer",<br/>      "roles/viewer"<br/>    ]<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/iam_service_account#Inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_vpc_peerings"></a> [vpc\_peerings](#input\_vpc\_peerings) | A map containing each VPC peering setting.<br/><br/>Example of variable deployment :<pre>vpc_peerings = {<br/>  "trust-to-spoke1" = {<br/>    local_network_key = "fw-trust-vpc"<br/>    peer_network_key  = "fw-spoke1-vpc"<br/><br/>    local_export_custom_routes                = true<br/>    local_import_custom_routes                = true<br/>    local_export_subnet_routes_with_public_ip = true<br/>    local_import_subnet_routes_with_public_ip = true<br/><br/>    peer_export_custom_routes                = true<br/>    peer_import_custom_routes                = true<br/>    peer_export_subnet_routes_with_public_ip = true<br/>    peer_import_subnet_routes_with_public_ip = true<br/>  }<br/>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc-peering#inputs)<br/><br/>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lbs_external_ips"></a> [lbs\_external\_ips](#output\_lbs\_external\_ips) | Public IP addresses of external network loadbalancers. |
| <a name="output_lbs_internal_ips"></a> [lbs\_internal\_ips](#output\_lbs\_internal\_ips) | Private IP addresses of internal network loadbalancers. |
| <a name="output_linux_vm_ips"></a> [linux\_vm\_ips](#output\_linux\_vm\_ips) | Private IP addresses of Linux VMs. |
| <a name="output_pubsub_subscription_id"></a> [pubsub\_subscription\_id](#output\_pubsub\_subscription\_id) | The resource ID of the Pub/Sub Subscription. |
| <a name="output_pubsub_topic_id"></a> [pubsub\_topic\_id](#output\_pubsub\_topic\_id) | The resource ID of the Pub/Sub Topic. |
<!-- END_TF_DOCS -->