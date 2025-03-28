---
short_title: Dedicated Firewall Option
type: refarch
show_in_hub: true
---
# Reference Architecture with Terraform: VM-Series in GCP, Centralized Architecture, Dedicated Inbound NGFW Option

Palo Alto Networks produces several [validated reference architecture design and deployment documentation guides](https://www.paloaltonetworks.com/resources/reference-architectures), which describe well-architected and tested deployments. When deploying VM-Series in a public cloud, the reference architectures guide users toward the best security outcomes, whilst reducing rollout time and avoiding common integration efforts.
The Terraform code presented here will deploy Palo Alto Networks VM-Series firewalls in GCP based on a centralized design with dedicated-inbound VM-Series; for a discussion of other options, please see the design guide from [the reference architecture guides](https://www.paloaltonetworks.com/resources/reference-architectures).

## Reference Architecture Design

![simple](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/assets/2110772/9530fc51-7267-4b74-a996-a522b97f0996)

This code implements:
- a _centralized design_, a hub-and-spoke topology with a shared VPC containing VM-Series to inspect all inbound, outbound, east-west, and enterprise traffic
- the _dedicated inbound option_, which separates inbound traffic flows onto a separate set of VM-Series

## Detailed Architecture and Design

### Centralized Design

This design uses a VPC Peering. Application functions are distributed across multiple projects that are connected in a logical hub-and-spoke topology. A security project acts as the hub, providing centralized connectivity and control for multiple application projects. You deploy all VM-Series firewalls within the security project. The spoke projects contain the workloads and necessary services to support the application deployment.
This design model integrates multiple methods to interconnect and control your application project VPC networks with resources in the security project. VPC Peering enables the private VPC network in the security project to peer with, and share routing information to, each application project VPC network. Using Shared VPC, the security project administrators create and share VPC network resources from within the security project to the application projects. The application project administrators can select the network resources and deploy the application workloads.

### Dedicated Inbound Option

The dedicated inbound option separates traffic flows across two separate sets of VM-Series firewalls. One set of VM-Series firewalls is dedicated to inbound traffic flows, allowing for greater flexibility and scaling of inbound traffic loads. The second set of VM-Series firewalls services all outbound, east-west, and enterprise network traffic flows. This deployment choice offers increased scale and operational resiliency and reduces the chances of high bandwidth use from the inbound traffic flows affecting other traffic flows within the deployment.

![gcp-dedicatedinbound](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/assets/2110772/9b331a6a-f29b-44d9-9b87-89833e84fa32)

With default variable values the topology consists of :
 - 5 VPC networks :
   - Management VPC
   - Untrust (outside) VPC
   - Trust (inside/security) VPC
   - Spoke-1 VPC
   - Spoke-2 VPC
 - 4 VM-Series firewalls
 - 2 Linux Ubuntu VMs (inside Spoke VPCs - for testing purposes)
 - one internal network loadbalancer (for outbound/east-west traffic)
 - one Global HTTP loadbalancer (for inbound traffic)


## Prerequisites

The following steps should be followed before deploying the Terraform code presented here.

1. Prepare [VM-Series licenses](https://support.paloaltonetworks.com/)
2. Configure the terraform [google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication-configuration)

## Bootstrap

With default settings, firewall instances will get the initial configuration from generated `init-cfg.txt` and `bootstrap.xml` files placed in Cloud Storage.

The `example.tfvars` file also contains commented out sample settings that can be used to register the firewalls to either Panorama or Strata Cloud Manager (SCM) and complete the configuration. To enable this, uncomment one of the sections and adjust `vmseries_common.bootstrap_options` and `vmseries.<fw-name>.bootstrap_options` parameters accordingly.

> SCM bootstrap is supported on PAN-OS version 11.0 and above.

## Build

1. Access Google Cloud Shell or any other environment which has access to your GCP project

2. Clone the repository:

```
git clone https://github.com/PaloAltoNetworks/terraform-google-swfw-modules
cd terraform-google-swfw-modules/examples/vpc-peering-dedicated
```

3. Copy the `example.tfvars` to `terraform.tfvars`.

`project`, `ssh_keys` and `source_ranges` should be modified for successful deployment and access to the instance. 

There are also a few variables that have some default values but which should also be changed as per deployment requirements

 - `region`
 - `vmseries.<fw-name>.bootstrap_options`
 - `linux_vms.<vm-name>.linux_disk_size`

4. Apply the terraform code:

```
terraform init
terraform apply -var-file=example.tfvars
```

4. Check the output plan and confirm the apply.

5. Check the successful application and outputs of the resulting infrastructure (number of resources can vary based on how many instances are defined in tfvars):

```
Apply complete! Resources: 104 added, 0 changed, 0 destroyed.

Outputs:

lbs_global_http = {
  "global-http" = "<GLOBAL_HTTP_LB_PUBLIC_IP>"
}
lbs_internal_ips = {
  "internal-lb" = "10.10.12.5"
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
  }
  "fw-vmseries-02" = {
    "0" = "10.10.11.3"
    "1" = "10.10.10.3"
    "2" = "10.10.12.3"
  }
  "fw-vmseries-03" = {
    "0" = "10.10.11.6"
    "1" = "10.10.10.6"
    "2" = "10.10.12.6"
  }
  "fw-vmseries-04" = {
    "0" = "10.10.11.7"
    "1" = "10.10.10.7"
    "2" = "10.10.12.7"
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
  "fw-vmseries-03" = {
    "0" = "<UNTRUST_PUBLIC_IP>"
    "1" = "<MGMT_PUBLIC_IP>"
  }
  "fw-vmseries-04" = {
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

## Global HTTP Loadbalancer

The GCP Global HTTP LB acts as a proxy and sends traffic to the VM-Series `Untrust` interfaces. In order to properly route traffic - configure a DNAT + SNAT Policy on the dedicated inbound firewall pair to send traffic towards a VM inside your network (SNAT is also required to properly route return traffic back to the proper firewall).

## Reference
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3, < 2.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bootstrap"></a> [bootstrap](#module\_bootstrap) | ../../modules/bootstrap | n/a |
| <a name="module_glb"></a> [glb](#module\_glb) | ../../modules/lb_http_ext_global | n/a |
| <a name="module_iam_service_account"></a> [iam\_service\_account](#module\_iam\_service\_account) | ../../modules/iam_service_account | n/a |
| <a name="module_lb_internal"></a> [lb\_internal](#module\_lb\_internal) | ../../modules/lb_internal | n/a |
| <a name="module_vmseries"></a> [vmseries](#module\_vmseries) | ../../modules/vmseries | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../modules/vpc | n/a |
| <a name="module_vpc_peering"></a> [vpc\_peering](#module\_vpc\_peering) | ../../modules/vpc-peering | n/a |

### Resources

| Name | Type |
|------|------|
| [google_compute_instance.linux_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_route.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [local_file.bootstrap_xml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_sensitive_file.init_cfg](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [google_compute_image.my_image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bootstrap_buckets"></a> [bootstrap\_buckets](#input\_bootstrap\_buckets) | A map containing each bootstrap bucket setting.<br><br>Example of variable deployment:<pre>bootstrap_buckets = {<br>  vmseries-bootstrap-bucket-01 = {<br>    bucket_name_prefix  = "bucket-01-"<br>    location            = "us"<br>    service_account_key = "sa-vmseries-01"<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/bootstrap#Inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_lbs_global_http"></a> [lbs\_global\_http](#input\_lbs\_global\_http) | A map containing each Global HTTP loadbalancer setting.<br><br>Example of variable deployment:<pre>lbs_global_http = {<br>  "global-http" = {<br>    name                  = "global-http"<br>    backends              = ["fw-vmseries-01", "fw-vmseries-02"]<br>    max_rate_per_instance = 5000<br>    backend_port_name     = "http"<br>    backend_protocol      = "HTTP"<br>    health_check_port     = 80<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_http_ext_global#inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_lbs_internal"></a> [lbs\_internal](#input\_lbs\_internal) | A map containing each internal loadbalancer setting.<br><br>Example of variable deployment :<pre>lbs_internal = {<br>  "internal-lb" = {<br>    name              = "internal-lb"<br>    health_check_port = "80"<br>    backends          = ["fw-vmseries-01", "fw-vmseries-02"]<br>    ip_address        = "10.10.12.5"<br>    subnetwork_key    = "fw-trust-sub"<br>    vpc_network_key   = "fw-trust-vpc"<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_internal#inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_linux_vms"></a> [linux\_vms](#input\_linux\_vms) | A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.<br><br>Example of variable deployment:<pre>linux_vms = {<br>  spoke1-vm = {<br>    linux_machine_type = "n2-standard-4"<br>    zone               = "us-east1-b"<br>    linux_disk_size    = "50" # Modify this value as per deployment requirements<br>    subnetwork         = "spoke1-sub"<br>    private_ip         = "192.168.1.2"<br>    scopes = [<br>      "https://www.googleapis.com/auth/compute.readonly",<br>      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br>      "https://www.googleapis.com/auth/devstorage.read_only",<br>      "https://www.googleapis.com/auth/logging.write",<br>      "https://www.googleapis.com/auth/monitoring.write",<br>    ]<br>    service_account_key = "sa-linux-01"<br>  }<br>}</pre> | `map(any)` | `{}` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A string to prefix resource namings. | `string` | `"example-"` | no |
| <a name="input_networks"></a> [networks](#input\_networks) | A map containing each network setting.<br><br>Example of variable deployment :<pre>networks = {<br>  fw-mgmt-vpc = {<br>    vpc_name = "fw-mgmt-vpc"<br>    create_network = true<br>    delete_default_routes_on_create = false<br>    mtu = "1460"<br>    routing_mode = "REGIONAL"<br>    subnetworks = {<br>      fw-mgmt-sub = {<br>        name = "fw-mgmt-sub"<br>        create_subnetwork = true<br>        ip_cidr_range = "10.10.10.0/28"<br>        region = "us-east1"<br>      }<br>    }<br>    firewall_rules = {<br>      allow-mgmt-ingress = {<br>        name = "allow-mgmt-ingress"<br>        source_ranges = ["10.10.10.0/24"]<br>        priority = "1000"<br>        allowed_protocol = "all"<br>        allowed_ports = []<br>      }<br>    }<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc#input_networks)<br><br>Multiple keys can be added and will be deployed by the code. | `any` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | The project name to deploy the infrastructure in to. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region into which to deploy the infrastructure in to. | `string` | `"us-central1"` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | A map containing each route setting. Note that you can only add routes using a next-hop type of internal load-balance rule.<br><br>Example of variable deployment :<pre>routes = {<br>  "default-route-trust" = {<br>    name = "fw-default-trust"<br>    destination_range = "0.0.0.0/0"<br>    vpc_network_key = "fw-trust-vpc"<br>    lb_internal_name = "internal-lb"<br>  }<br>}</pre>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_service_accounts"></a> [service\_accounts](#input\_service\_accounts) | A map containing each service account setting.<br><br>Example of variable deployment :<pre>service_accounts = {<br>  "sa-vmseries-01" = {<br>    service_account_id = "sa-vmseries-01"<br>    display_name       = "VM-Series SA"<br>    roles = [<br>      "roles/compute.networkViewer",<br>      "roles/logging.logWriter",<br>      "roles/monitoring.metricWriter",<br>      "roles/monitoring.viewer",<br>      "roles/viewer"<br>    ]<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/iam_service_account#Inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_vmseries"></a> [vmseries](#input\_vmseries) | A map containing each individual vmseries setting.<br><br>Example of variable deployment :<pre>vmseries = {<br>  "fw-vmseries-01" = {<br>    name             = "fw-vmseries-01"<br>    zone             = "us-east1-b"<br>    machine_type     = "n2-standard-4"<br>    min_cpu_platform = "Intel Cascade Lake"<br>    tags                 = ["vmseries"]<br>    service_account_key  = "sa-vmseries-01"<br>    scopes = [<br>      "https://www.googleapis.com/auth/compute.readonly",<br>      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br>      "https://www.googleapis.com/auth/devstorage.read_only",<br>      "https://www.googleapis.com/auth/logging.write",<br>      "https://www.googleapis.com/auth/monitoring.write",<br>    ]<br>    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"<br>    bootstrap_options = {<br>      panorama-server = "1.1.1.1"<br>      dns-primary     = "8.8.8.8"<br>      dns-secondary   = "8.8.4.4"<br>    }<br>    bootstrap_template_map = {<br>      trust_gcp_router_ip   = "10.10.12.1"<br>      untrust_gcp_router_ip = "10.10.11.1"<br>      private_network_cidr  = "192.168.0.0/16"<br>      untrust_loopback_ip   = "1.1.1.1/32" #This is placeholder IP - you must replace it on the vmseries config with the LB public IP address after the infrastructure is deployed<br>      trust_loopback_ip     = "10.10.12.5/32"<br>    }<br>    named_ports = [<br>      {<br>        name = "http"<br>        port = 80<br>      },<br>      {<br>        name = "https"<br>        port = 443<br>      }<br>    ]<br>    network_interfaces = [<br>      {<br>        vpc_network_key  = "fw-untrust-vpc"<br>        subnetwork_key       = "fw-untrust-sub"<br>        private_ip       = "10.10.11.2"<br>        create_public_ip = true<br>      },<br>      {<br>        vpc_network_key  = "fw-mgmt-vpc"<br>        subnetwork_key       = "fw-mgmt-sub"<br>        private_ip       = "10.10.10.2"<br>        create_public_ip = true<br>      },<br>      {<br>        vpc_network_key = "fw-trust-vpc"<br>        subnetwork_key = "fw-trust-sub"<br>        private_ip = "10.10.12.2"<br>      },<br>    ]<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vmseries#inputs)<br><br>The bootstrap\_template\_map contains variables that will be applied to the bootstrap template. Each firewall Day 0 bootstrap will be parametrised based on these inputs.<br>Multiple keys can be added and will be deployed by the code. | <pre>map(object({<br>    name = string<br>    zone = string<br>    network_interfaces = optional(list(object({<br>      vpc_network_key  = string<br>      subnetwork_key   = string<br>      private_ip       = string<br>      create_public_ip = optional(bool, false)<br>      public_ip        = optional(string)<br>    })))<br>    ssh_keys            = optional(string)<br>    vmseries_image      = optional(string)<br>    machine_type        = optional(string)<br>    min_cpu_platform    = optional(string)<br>    tags                = optional(list(string))<br>    service_account_key = optional(string)<br>    service_account     = optional(string)<br>    scopes              = optional(list(string))<br>    bootstrap_options = optional(object({<br>      type                                  = optional(string)<br>      mgmt-interface-swap                   = optional(string)<br>      plugin-op-commands                    = optional(string)<br>      panorama-server                       = optional(string)<br>      auth-key                              = optional(string)<br>      dgname                                = optional(string)<br>      tplname                               = optional(string)<br>      dhcp-send-hostname                    = optional(string)<br>      dhcp-send-client-id                   = optional(string)<br>      dhcp-accept-server-hostname           = optional(string)<br>      dhcp-accept-server-domain             = optional(string)<br>      authcodes                             = optional(string)<br>      vm-series-auto-registration-pin-id    = optional(string)<br>      vm-series-auto-registration-pin-value = optional(string)<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_vmseries_common"></a> [vmseries\_common](#input\_vmseries\_common) | A map containing common vmseries settings.<br><br>Example of variable deployment :<pre>vmseries_common = {<br>  ssh_keys            = "admin:AAABBB..."<br>  vmseries_image      = "vmseries-flex-byol-10210h9"<br>  machine_type        = "n2-standard-4"<br>  min_cpu_platform    = "Intel Cascade Lake"<br>  service_account_key = "sa-vmseries-01"<br>  bootstrap_options = {<br>    type                = "dhcp-client"<br>    mgmt-interface-swap = "enable"<br>  }<br>}</pre>Majority of settings can be moved between this common and individual instance (ie. `var.vmseries`) variables. If values for the same item are specified in both of them, one from the latter will take precedence. | <pre>object({<br>    ssh_keys            = optional(string)<br>    vmseries_image      = optional(string)<br>    machine_type        = optional(string)<br>    min_cpu_platform    = optional(string)<br>    tags                = optional(list(string))<br>    service_account_key = optional(string)<br>    scopes              = optional(list(string))<br>    bootstrap_options = optional(object({<br>      type                                  = optional(string)<br>      mgmt-interface-swap                   = optional(string)<br>      plugin-op-commands                    = optional(string)<br>      panorama-server                       = optional(string)<br>      auth-key                              = optional(string)<br>      dgname                                = optional(string)<br>      tplname                               = optional(string)<br>      dhcp-send-hostname                    = optional(string)<br>      dhcp-send-client-id                   = optional(string)<br>      dhcp-accept-server-hostname           = optional(string)<br>      dhcp-accept-server-domain             = optional(string)<br>      authcodes                             = optional(string)<br>      vm-series-auto-registration-pin-id    = optional(string)<br>      vm-series-auto-registration-pin-value = optional(string)<br>    }))<br>  })</pre> | `{}` | no |
| <a name="input_vpc_peerings"></a> [vpc\_peerings](#input\_vpc\_peerings) | A map containing each VPC peering setting.<br><br>Example of variable deployment :<pre>vpc_peerings = {<br>  "trust-to-spoke1" = {<br>    local_network_key = "fw-trust-vpc"<br>    peer_network_key  = "fw-spoke1-vpc"<br><br>    local_export_custom_routes                = true<br>    local_import_custom_routes                = true<br>    local_export_subnet_routes_with_public_ip = true<br>    local_import_subnet_routes_with_public_ip = true<br><br>    peer_export_custom_routes                = true<br>    peer_import_custom_routes                = true<br>    peer_export_subnet_routes_with_public_ip = true<br>    peer_import_subnet_routes_with_public_ip = true<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc-peering#inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_lbs_global_http"></a> [lbs\_global\_http](#output\_lbs\_global\_http) | Public IP addresses of external Global HTTP(S) loadbalancers. |
| <a name="output_lbs_internal_ips"></a> [lbs\_internal\_ips](#output\_lbs\_internal\_ips) | Private IP addresses of internal network loadbalancers. |
| <a name="output_linux_vm_ips"></a> [linux\_vm\_ips](#output\_linux\_vm\_ips) | Private IP addresses of Linux VMs. |
| <a name="output_vmseries_private_ips"></a> [vmseries\_private\_ips](#output\_vmseries\_private\_ips) | Private IP addresses of the vmseries instances. |
| <a name="output_vmseries_public_ips"></a> [vmseries\_public\_ips](#output\_vmseries\_public\_ips) | Public IP addresses of the vmseries instances. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
