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

## Bootstrap

With default settings, firewall instances will get the initial configuration from generated `init-cfg.txt` and `bootstrap.xml` files placed in Cloud Storage.

The `example.tfvars` file also contains commented out sample settings that can be used to register the firewalls to either Panorama or Strata Cloud Manager (SCM) and complete the configuration. To enable this, uncomment one of the sections and adjust `vmseries_common.bootstrap_options` and `vmseries.<fw-name>.bootstrap_options` parameters accordingly.

> SCM bootstrap is supported on PAN-OS version 11.0 and above.

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

5. Check the successful application and outputs of the resulting infrastructure (number of resources can vary based on how many instances are defined in tfvars):

```
Apply complete! Resources: 77 added, 0 changed, 0 destroyed.

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
[`vmseries_common`](#vmseries_common) | `any` | A map containing common vmseries settings.
[`vmseries`](#vmseries) | `any` | A map containing each individual vmseries setting.
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


Type: any

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



Type: any

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
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    service_account_key = "sa-linux-01"
  }
}
```


Type: map(any)

Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>
