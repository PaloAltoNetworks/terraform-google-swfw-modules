---
show_in_hub: false
---
# Reference Architecture with Terraform: VM-Series in GCP, Centralized Architecture, Common NGFW with autoscale Option

Palo Alto Networks produces several [validated reference architecture design and deployment documentation guides](https://www.paloaltonetworks.com/resources/reference-architectures), which describe well-architected and tested deployments. When deploying VM-Series in a public cloud, the reference architectures guide users toward the best security outcomes, whilst reducing rollout time and avoiding common integration efforts.
The Terraform code presented here will deploy Palo Alto Networks VM-Series firewalls in GCP based on a centralized design with common VM-Series and autoscaling capabilities for all traffic; for a discussion of other options, please see the design guide from [the reference architecture guides](https://www.paloaltonetworks.com/resources/reference-architectures).

## Detailed Architecture and Design

### Centralized Design

This design uses a VPC Peering. Application functions are distributed across multiple projects that are connected in a logical hub-and-spoke topology. A security project acts as the hub, providing centralized connectivity and control for multiple application projects. You deploy all VM-Series firewalls within the security project. The spoke projects contain the workloads and necessary services to support the application deployment.
This design model integrates multiple methods to interconnect and control your application project VPC networks with resources in the security project. VPC Peering enables the private VPC network in the security project to peer with, and share routing information to, each application project VPC network. Using Shared VPC, the security project administrators create and share VPC network resources from within the security project to the application projects. The application project administrators can select the network resources and deploy the application workloads.

### Common Option with autoscaling

The common firewall option with autoscaling leverages a single set autoscale group of VM-Series firewalls. Compared to the standard common firewall option - the autoscaling solved the issue of resource bottleneck given by a single set of firewalls, being able to scale horizontally based on configurable metrics.

![VM-Series-Common-Firewall-Option-With-Autoscaling](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/assets/2110772/b4112be1-4189-4197-85e8-0154a3665c05)

The scope of this code is to deploy an example of the [VM-Series Common Firewall Option](https://www.paloaltonetworks.com/apps/pan/public/downloadResource?pagePath=/content/pan/en_US/resources/guides/gcp-architecture-guide#Design%20Model) architecture within a GCP project, but using an autoscaling group of instances instead of a single pair of firewall.

The example makes use of VM-Series basic [bootstrap process](https://docs.paloaltonetworks.com/vm-series/10-2/vm-series-deployment/bootstrap-the-vm-series-firewall/bootstrap-the-vm-series-firewall-on-google) using metadata information to pass bootstrap parameters to the autoscale instances.

With default variable values the topology consists of :
 - 5 VPC networks :
   - Management VPC
   - Untrust (outside) VPC
   - Trust (inside/security) VPC
   - Spoke-1 VPC
   - Spoke-2 VPC
 - 1 Autoscaling Group
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
cd terraform-google-swfw-modules/examples/vpc_peering_common_with_autoscale
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
Apply complete! Resources: 48 added, 0 changed, 0 destroyed.

Outputs:

lbs_external_ips = {
  "external-lb" = {
    "all-ports" = "<EXTERNAL_LB_PUBLIC_IP>"
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
  "fw-autoscale-common" = "projects/<project_id>/subscriptions/fw-autoscale-common-mig"
}
pubsub_topic_id = {
  "fw-autoscale-common" = "projects/<project_id>/topics/fw-autoscale-common-mig"
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

For the VM-Series that are backend instance group members of the public-facing loadbalancer - go to Network -> Interfaces -> Loopback and add the value of `1.1.1.1` with the value from the `EXTERNAL_LB_PUBLIC_IP` from the terraform outputs.

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
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3, < 2.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_autoscale"></a> [autoscale](#module\_autoscale) | ../../modules/autoscale/ | n/a |
| <a name="module_iam_service_account"></a> [iam\_service\_account](#module\_iam\_service\_account) | ../../modules/iam_service_account | n/a |
| <a name="module_lb_external"></a> [lb\_external](#module\_lb\_external) | ../../modules/lb_external | n/a |
| <a name="module_lb_internal"></a> [lb\_internal](#module\_lb\_internal) | ../../modules/lb_internal | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../modules/vpc | n/a |
| <a name="module_vpc_peering"></a> [vpc\_peering](#module\_vpc\_peering) | ../../modules/vpc-peering | n/a |

### Resources

| Name | Type |
|------|------|
| [google_compute_instance.linux_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_route.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_image.my_image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscale"></a> [autoscale](#input\_autoscale) | A map containing each vmseries autoscale setting.<br>Zonal or regional managed instance group type is controolled from the `autoscale_regional_mig` variable for all autoscale instances.<br><br>Example of variable deployment :<pre>autoscale = {<br>  fw-autoscale-common = {<br>    name = "fw-autoscale-common"<br>    zones = {<br>      zone1 = "us-east4-b"<br>      zone2 = "us-east4-c"<br>    }<br>    named_ports = [<br>      {<br>        name = "http"<br>        port = 80<br>      },<br>      {<br>        name = "https"<br>        port = 443<br>      }<br>    ]<br>    service_account_key   = "sa-vmseries-01"<br>    min_vmseries_replicas = 2<br>    max_vmseries_replicas = 4<br>    create_pubsub_topic   = true<br>    autoscaler_metrics = {<br>      "custom.googleapis.com/VMSeries/panSessionUtilization" = {<br>        target = 70<br>      }<br>      "custom.googleapis.com/VMSeries/panSessionThroughputKbps" = {<br>        target = 700000<br>      }<br>    }<br>    bootstrap_options = {<br>      type                        = "dhcp-client"<br>      dhcp-send-hostname          = "yes"<br>      dhcp-send-client-id         = "yes"<br>      dhcp-accept-server-hostname = "yes"<br>      dhcp-accept-server-domain   = "yes"<br>      mgmt-interface-swap         = "enable"<br>      panorama-server             = "1.1.1.1"<br>      ssh-keys                    = "admin:<your_ssh_key>" # Replace this value with client data<br>    }<br>    network_interfaces = [<br>      {<br>        vpc_network_key  = "fw-untrust-vpc"<br>        subnetwork_key   = "fw-untrust-sub"<br>        create_public_ip = true<br>      },<br>      {<br>        vpc_network_key  = "fw-mgmt-vpc"<br>        subnetwork_key   = "fw-mgmt-sub"<br>        create_public_ip = true<br>      },<br>      {<br>        vpc_network_key = "fw-trust-vpc"<br>        subnetwork_key  = "fw-trust-sub"<br>      }<br>    ]<br>  }<br>}</pre> | `any` | `{}` | no |
| <a name="input_autoscale_common"></a> [autoscale\_common](#input\_autoscale\_common) | A map containing common vmseries autoscale setting.<br>Majority of settings can be moved between this common and individual autoscale setup (ie. `var.autoscale`) variables. If values for the same item are specified in both of them, one from the latter will take precedence.<br><br>Example of variable deployment :<pre>autoscale_common = {<br>  image            = "vmseries-flex-byol-1114h7"<br>  machine_type     = "n2-standard-4"<br>  min_cpu_platform = "Intel Cascade Lake"<br>  disk_type        = "pd-ssd"<br>  scopes = [<br>    "https://www.googleapis.com/auth/compute.readonly",<br>    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br>    "https://www.googleapis.com/auth/devstorage.read_only",<br>    "https://www.googleapis.com/auth/logging.write",<br>    "https://www.googleapis.com/auth/monitoring.write",<br>  ]<br>  tags               = ["vmseries-autoscale"]<br>  update_policy_type = "OPPORTUNISTIC"<br>  cooldown_period    = 480<br>  bootstrap_options  = [<br>    panorama_server  = "1.1.1.1"<br>  ]<br>}</pre> | `any` | `{}` | no |
| <a name="input_autoscale_regional_mig"></a> [autoscale\_regional\_mig](#input\_autoscale\_regional\_mig) | Sets the managed instance group type to either a regional (if `true`) or a zonal (if `false`).<br>For more information please see [About regional MIGs](https://cloud.google.com/compute/docs/instance-groups/regional-migs#why_choose_regional_managed_instance_groups). | `bool` | `true` | no |
| <a name="input_lbs_external"></a> [lbs\_external](#input\_lbs\_external) | A map containing each external loadbalancer setting.<br><br>Example of variable deployment :<pre>lbs_external = {<br>  "external-lb" = {<br>    name     = "external-lb"<br>    backends = ["fw-vmseries-01", "fw-vmseries-02"]<br>    rules = {<br>      "all-ports" = {<br>        ip_protocol = "L3_DEFAULT"<br>      }<br>    }<br>    http_health_check_port         = "80"<br>    http_health_check_request_path = "/php/login.php"<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_external#inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_lbs_internal"></a> [lbs\_internal](#input\_lbs\_internal) | A map containing each internal loadbalancer setting.<br>Note : private IP reservation is not by default within the example as it may overlap with autoscale IP allocation.<br><br>Example of variable deployment :<pre>lbs_internal = {<br>  "internal-lb" = {<br>    name              = "internal-lb"<br>    health_check_port = "80"<br>    backends          = ["fw-vmseries-01", "fw-vmseries-02"]<br>    subnetwork_key    = "fw-trust-sub"<br>    vpc_network_key   = "fw-trust-vpc"<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/lb_internal#inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_linux_vms"></a> [linux\_vms](#input\_linux\_vms) | A map containing each Linux VM configuration that will be placed in SPOKE VPCs for testing purposes.<br><br>Example of varaible deployment:<pre>linux_vms = {<br>  spoke1-vm = {<br>    linux_machine_type = "n2-standard-4"<br>    zone               = "us-east1-b"<br>    linux_disk_size    = "50" # Modify this value as per deployment requirements<br>    vpc_network_key    = "fw-spoke1-vpc"<br>    subnetwork_key     = "fw-spoke1-sub"<br>    private_ip         = "192.168.1.2"<br>    scopes = [<br>      "https://www.googleapis.com/auth/compute.readonly",<br>      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",<br>      "https://www.googleapis.com/auth/devstorage.read_only",<br>      "https://www.googleapis.com/auth/logging.write",<br>      "https://www.googleapis.com/auth/monitoring.write",<br>    ]<br>    service_account_key = "sa-linux-01"<br>  }<br>}</pre> | `map(any)` | `{}` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A string to prefix resource namings. | `string` | `"example-"` | no |
| <a name="input_networks"></a> [networks](#input\_networks) | A map containing each network setting.<br><br>Example of variable deployment :<pre>networks = {<br>  fw-mgmt-vpc = {<br>    vpc_name = "fw-mgmt-vpc"<br>    create_network = true<br>    delete_default_routes_on_create = false<br>    mtu = "1460"<br>    routing_mode = "REGIONAL"<br>    subnetworks = {<br>      fw-mgmt-sub = {<br>        name = "fw-mgmt-sub"<br>        create_subnetwork = true<br>        ip_cidr_range = "10.10.10.0/28"<br>        region = "us-east1"<br>      }<br>    }<br>    firewall_rules = {<br>      allow-mgmt-ingress = {<br>        name = "allow-mgmt-ingress"<br>        source_ranges = ["10.10.10.0/24"]<br>        priority = "1000"<br>        allowed_protocol = "all"<br>        allowed_ports = []<br>      }<br>    }<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc#input_networks)<br><br>Multiple keys can be added and will be deployed by the code. | `any` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | The project name to deploy the infrastructure in to. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region into which to deploy the infrastructure in to. | `string` | `"us-central1"` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | A map containing each route setting. Note that you can only add routes using a next-hop type of internal load-balance rule.<br><br>Example of variable deployment :<pre>routes = {<br>  "default-route-trust" = {<br>    name = "fw-default-trust"<br>    destination_range = "0.0.0.0/0"<br>    vpc_network_key = "fw-trust-vpc"<br>    lb_internal_name = "internal-lb"<br>  }<br>}</pre>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_service_accounts"></a> [service\_accounts](#input\_service\_accounts) | A map containing each service account setting.<br><br>Example of variable deployment :<pre>service_accounts = {<br>  "sa-vmseries-01" = {<br>    service_account_id = "sa-vmseries-01"<br>    display_name       = "VM-Series SA"<br>    roles = [<br>      "roles/compute.networkViewer",<br>      "roles/logging.logWriter",<br>      "roles/monitoring.metricWriter",<br>      "roles/monitoring.viewer",<br>      "roles/viewer"<br>    ]<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/iam_service_account#Inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |
| <a name="input_vpc_peerings"></a> [vpc\_peerings](#input\_vpc\_peerings) | A map containing each VPC peering setting.<br><br>Example of variable deployment :<pre>vpc_peerings = {<br>  "trust-to-spoke1" = {<br>    local_network_key = "fw-trust-vpc"<br>    peer_network_key  = "fw-spoke1-vpc"<br><br>    local_export_custom_routes                = true<br>    local_import_custom_routes                = true<br>    local_export_subnet_routes_with_public_ip = true<br>    local_import_subnet_routes_with_public_ip = true<br><br>    peer_export_custom_routes                = true<br>    peer_import_custom_routes                = true<br>    peer_export_subnet_routes_with_public_ip = true<br>    peer_import_subnet_routes_with_public_ip = true<br>  }<br>}</pre>For a full list of available configuration items - please refer to [module documentation](https://github.com/PaloAltoNetworks/terraform-google-swfw-modules/tree/main/modules/vpc-peering#inputs)<br><br>Multiple keys can be added and will be deployed by the code. | `map(any)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_lbs_external_ips"></a> [lbs\_external\_ips](#output\_lbs\_external\_ips) | Public IP addresses of external network loadbalancers. |
| <a name="output_lbs_internal_ips"></a> [lbs\_internal\_ips](#output\_lbs\_internal\_ips) | Private IP addresses of internal network loadbalancers. |
| <a name="output_linux_vm_ips"></a> [linux\_vm\_ips](#output\_linux\_vm\_ips) | Private IP addresses of Linux VMs. |
| <a name="output_pubsub_subscription_id"></a> [pubsub\_subscription\_id](#output\_pubsub\_subscription\_id) | The resource ID of the Pub/Sub Subscription. |
| <a name="output_pubsub_topic_id"></a> [pubsub\_topic\_id](#output\_pubsub\_topic\_id) | The resource ID of the Pub/Sub Topic. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
