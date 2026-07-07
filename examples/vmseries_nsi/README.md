---
short_title: VM-Series with Network Security Integration (NSI) and NCC
type: example
show_in_hub: true
---
# Reference Architecture with Terraform: VM-Series in GCP with Network Security Integration (NSI) and Network Connectivity Center (NCC)

Palo Alto Networks produces several [validated reference architecture design and deployment documentation guides](https://www.paloaltonetworks.com/resources/reference-architectures), which describe well-architected and tested deployments. When deploying VM-Series in a public cloud, the reference architectures guide users toward the best security outcomes while reducing rollout time and avoiding common integration efforts.

This Terraform example deploys Palo Alto Networks VM-Series firewalls in GCP using **Google Cloud Network Security Integration (NSI)** — a transparent, GENEVE-based traffic-interception mechanism that steers workload VPC traffic through the VM-Series fleet for deep-packet inspection, without changing routes, VPC peerings, or workload VM configurations. It also deploys **Network Connectivity Center (NCC)** to provide transitive hub-and-spoke connectivity between workload VPCs.

## Reference Architecture Design

The deployment implements a centralized security model in which a dedicated producer/security VPC hosts the VM-Series fleet, and one or more consumer/spoke VPCs have their traffic transparently intercepted and inspected.

This architecture is particularly suited for:
- East-west traffic inspection between spoke VPCs without additional hops or route policy changes.
- Scalable security for many consumer VPCs using a single VM-Series fleet.
- Environments where workload teams manage their own VPCs and do not want to manage routes or peerings.

## Detailed Architecture and Design

### Network Security Integration (NSI)

NSI uses a two-sided model:

**Producer side** (inside the security/producer VPC):

1. **GENEVE ILB** — one Internal Passthrough Network Load Balancer per zone, listening on UDP/6081. The VM-Series receive GENEVE-encapsulated copies of intercepted flows on this interface.
2. **Intercept deployment** — one `google_network_security_intercept_deployment` per zone, referencing the zone-specific ILB forwarding rule. This zone-level resource is what requires a unique forwarding rule per zone.
3. **Intercept deployment group** — a single global resource that aggregates all zonal deployments for the producer VPC.
4. **Intercept endpoint group** — the logical handle that consumer associations reference; links the consumer intercept request to the deployment group.
5. **Security profile + group** — the policy object that maps the endpoint group to PAN-OS for inspection.

**Consumer side** (inside each workload/spoke VPC):

6. **Intercept endpoint group association** — activates NSI interception for the consumer VPC. Each association can take **5–15 minutes to reach `ACTIVE` state** on first apply.
7. **Global network firewall policy** — rules with `action = apply_security_profile_group` steer matched flows into NSI. Both ingress and egress rules are configured by default.
8. **Firewall policy association** — attaches the policy to the consumer VPC network.

### Network Connectivity Center (NCC)

NCC provides transitive hub-and-spoke routing between consumer VPCs without requiring explicit VPC peerings between each pair. The NCC hub uses **MESH** topology by default, which lets all spokes exchange routes and reach one another through the hub. Combined with NSI, this means inter-spoke traffic is transparently intercepted and inspected by VM-Series as it transits the NCC routing plane.

### Bootstrap

The VM-Series use **metadata-only bootstrap** (no GCS bucket required). The mandatory `plugin-op-commands = "geneve-inspect:enable"` option is automatically merged into every instance's bootstrap metadata by the `main.tf` and activates GENEVE decapsulation on PAN-OS 11.2+.

### Default Topology

With the provided `example.tfvars`, the deployment creates:

- 1 producer/security VPC with `mgmt` and `data` subnets
- 2 VM-Series firewalls (`n2-standard-8`) — one in `us-central1-a`, one in `us-central1-b`
- 2 GENEVE ILBs (one per zone, UDP/6081)
- 1 NSI intercept stack (deployment group, endpoint group, security profile + group)
- 2 consumer/spoke VPCs (`spoke-1`, `spoke-2`), each with an NSI endpoint-group association and a global firewall policy
- 1 NCC hub in MESH topology with 2 VPC spokes
- 2 optional Linux test VMs (one per spoke, for end-to-end validation)

## Prerequisites

Before deploying, ensure the following:

1. **PAN-OS image** — the `vmseries_image` must be PAN-OS **≥ 11.2** (e.g. `vmseries-flex-byol-1120`). NSI GENEVE decapsulation is not available on earlier releases.

2. **GCP APIs** — enable the following APIs in your project:
   ```
   gcloud services enable \
     compute.googleapis.com \
     networksecurity.googleapis.com \
     networkconnectivity.googleapis.com \
     iam.googleapis.com
   ```

3. **GCP authentication** — configure the [Google Terraform provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication-configuration).

4. **Panorama (optional)** — if using Panorama-managed bootstrap, ensure Panorama is reachable from the `mgmt` subnet and fill in `panorama-server`, `tplname`, `dgname`, and `vm-auth-key` under `vmseries_common.bootstrap_options`.

5. **VM-Series license** — prepare [VM-Series licenses](https://support.paloaltonetworks.com/) or use an evaluation image.

## Usage

1. Access Google Cloud Shell or any environment with access to your GCP project.

2. Clone the repository:
   ```
   git clone https://github.com/PaloAltoNetworks/terraform-google-swfw-modules
   cd terraform-google-swfw-modules/examples/vmseries_nsi
   ```

3. Copy `example.tfvars` to `terraform.tfvars` and update the required values:
   ```
   cp example.tfvars terraform.tfvars
   ```
   At minimum, update:
   - `project` — your GCP project ID
   - `ssh_keys` — your SSH public key
   - `vmseries_image` — a PAN-OS ≥ 11.2 image name available in your project
   - `vmseries_common.bootstrap_options.panorama-server` — your Panorama IP (or leave empty for standalone bootstrap)
   - `producer_vpc.firewall_rules.allow-mgmt-ssh-https.source_ranges` — your operator/jump-host CIDRs

4. Deploy:
   ```
   terraform init
   terraform apply
   ```

5. Confirm the plan and approve. The apply takes **10–20 minutes** — longer than typical because the `intercept_endpoint_group_association` resources wait for GCP to activate the NSI intercept path for each consumer VPC.

## Expected Outputs

After a successful `terraform apply`, you should see output similar to:

```
Apply complete! Resources: 44 added, 0 changed, 0 destroyed.

Outputs:

geneve_ilb_addresses = {
  "fw-01" = "10.0.1.10"
  "fw-02" = "10.0.1.11"
}
linux_vm_ips = {
  "spoke1-vm" = "192.168.1.2"
  "spoke2-vm" = "192.168.2.2"
}
ncc_hub_id      = "projects/<PROJECT>/locations/global/hubs/pan-nsi-ncc-hub"
ncc_spoke_names = {
  "spoke-1" = "pan-nsi-spoke-spoke-1"
  "spoke-2" = "pan-nsi-spoke-spoke-2"
}
nsi_deployment_group_id       = "projects/<PROJECT>/locations/global/interceptDeploymentGroups/pan-nsi-intercept-dgrp"
nsi_endpoint_group_id         = "projects/<PROJECT>/locations/global/interceptEndpointGroups/pan-nsi-intercept-egrp"
nsi_security_profile_group_id = "//networksecurity.googleapis.com/projects/<PROJECT>/locations/global/securityProfileGroups/pan-nsi-intercept-pgrp"
vmseries_private_ips = {
  "fw-01" = { "0" = "10.0.0.2", "1" = "10.0.1.2" }
  "fw-02" = { "0" = "10.0.0.3", "1" = "10.0.1.3" }
}
vmseries_public_ips = {
  "fw-01" = {}
  "fw-02" = {}
}
```

## Post-Build: VM-Series Bootstrap Verification

Connect to each VM-Series instance via SSH using your private key and verify the bootstrap completed successfully:

```
ssh admin@<MGMT_IP> -i /path/to/your/private_key
```

Wait up to 10–15 minutes for the bootstrap to finish. The key indicator is `Auto-commit Successful`:

```
admin@PA-VM> show system bootstrap status

Bootstrap Phase               Status         Details
===============               ======         =======
Media Detection               Success        Media detected successfully
Media Sanity Check            Success        Media sanity check successful
Parsing of Initial Config     Successful
Auto-commit                   Successful
```

Set the admin password:

```
admin@PA-VM> configure
[edit]
admin@PA-VM# set mgt-config users admin password
Enter password   :
Confirm password :

[edit]
admin@PA-VM# commit
Configuration committed successfully
```

If `create_mgmt_public_ip = false`, use IAP tunneling to reach the management IP:

```
gcloud compute ssh <NAME-PREFIX>fw-01 --zone=us-central1-a --tunnel-through-iap
```

## Post-Build: PAN-OS GENEVE Health-Check Configuration

For the GENEVE ILBs to mark the VM-Series backends as healthy, you must configure a **loopback interface** per ILB forwarding rule IP with an HTTPS management profile that allows the GCP health-check source ranges.

For each IP address in the `geneve_ilb_addresses` output:

1. In PAN-OS, go to **Network → Interfaces → Loopback** and add a loopback interface with the ILB IP as its address.
2. Create a **Management Profile** that allows HTTPS from these GCP health-check ranges:
   - `35.191.0.0/16`
   - `130.211.0.0/22`
   - `209.85.152.0/22`
   - `209.85.204.0/22`
3. Assign the management profile to the loopback interface.
4. Commit the configuration on both firewalls.

Once healthy, confirm the backend status from the CLI:

```
gcloud compute backend-services get-health pan-nsi-geneve-ilb-fw-01-bs --region us-central1
```

You should see `healthState: HEALTHY` for both instances.

## Verify NSI Interception End-to-End

After the health checks pass, verify that traffic between consumer VMs is intercepted by VM-Series.

1. SSH into the `spoke1-vm` test VM via IAP:
   ```
   gcloud compute ssh pan-nsi-spoke1-vm --zone=us-central1-a --tunnel-through-iap
   ```

2. From `spoke1-vm`, curl the `spoke2-vm` internal IP (from `linux_vm_ips` output):
   ```
   curl http://192.168.2.2
   ```
   You should receive the `spoke-2-vm` response from the nginx startup script.

3. In PAN-OS, go to **Monitor → Traffic** and confirm the flow appears. The source IP will be `192.168.1.2` (spoke1-vm) and the destination will be `192.168.2.2` (spoke2-vm). The traffic should be logged as inspected, confirming NSI is steering spoke-to-spoke traffic through PAN-OS.

## Verify NCC Hub and Spoke Connectivity

Confirm the NCC hub and spokes are in `ACTIVE` state:

```
gcloud network-connectivity hubs describe pan-nsi-ncc-hub --project <PROJECT>

gcloud network-connectivity spokes list \
  --hub=pan-nsi-ncc-hub \
  --global \
  --project <PROJECT>
```

Both spokes should show `state: ACTIVE`. The NCC mesh routing is what enables `spoke1-vm` to reach `spoke2-vm` without any explicit VPC peering between the two spoke VPCs.

## Cleanup

To destroy all resources:

```
terraform destroy
```

> **Note:** The `intercept_endpoint_group_association` resources can take several minutes to fully delete after `terraform destroy` completes. If you re-apply with the same `name_prefix` immediately after a destroy, you may encounter a conflict on the association resource names. Wait a few minutes before re-applying.

## Reference

### Requirements

- `terraform`, version: >= 1.3, < 2.0
- `google`, version: >= 6.15
- `google-beta`, version: >= 6.15

### Providers

- `google`, version: >= 6.15

### Modules
Name | Version | Source | Description
--- | --- | --- | ---
`consumer_vpcs` | - | ../../modules/vpc | 
`data_vpc` | - | ../../modules/vpc | 
`geneve_ilb` | - | ../../modules/lb_internal | 
`iam_service_account` | - | ../../modules/iam_service_account | 
`mgmt_vpc` | - | ../../modules/vpc | 
`ncc` | - | ../../modules/ncc_connectivity | 
`nsi` | - | ../../modules/nsi_intercept | 
`vmseries` | - | ../../modules/vmseries | 

### Resources

- `compute_instance` (managed)
- `compute_region_health_check` (managed)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`consumer_vpcs`](#consumer_vpcs) | `map` | Map of consumer/spoke VPC key => VPC and subnet configuration.
[`data_vpc`](#data_vpc) | `object` | Data/GENEVE VPC for VM-Series NIC1.
[`mgmt_vpc`](#mgmt_vpc) | `object` | Management VPC for VM-Series NIC0.
[`name_prefix`](#name_prefix) | `string` | Short prefix applied to every resource name (e.
[`project`](#project) | `string` | GCP project ID for all resources.
[`region`](#region) | `string` | GCP region for subnets, ILBs, and Cloud Router.
[`ssh_keys`](#ssh_keys) | `string` | SSH public key(s) for instance-level access (format: "user:ssh-ed25519 AAAA.
[`vmseries`](#vmseries) | `map` | Map of VM-Series instance key => zone and per-instance bootstrap overrides.
[`vmseries_image`](#vmseries_image) | `string` | Full VM-Series image name.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`create_mgmt_public_ip`](#create_mgmt_public_ip) | `bool` | Assign a public IP to the mgmt NIC.
[`enable_ncc`](#enable_ncc) | `bool` | Deploy a Network Connectivity Center hub and attach each consumer VPC as a spoke.
[`firewall_policy_rules`](#firewall_policy_rules) | `list` | Firewall policy rules applied to each consumer VPC.
[`linux_vms`](#linux_vms) | `map` | Optional Linux test VMs to deploy in consumer VPCs for validating NSI traffic interception end-to-end.
[`ncc_topology`](#ncc_topology) | `string` | NCC hub preset topology.
[`service_account`](#service_account) | `object` | Service account configuration for the VM-Series instances.
[`vmseries_common`](#vmseries_common) | `object` | Common settings shared across all VM-Series instances.

### Outputs

Name |  Description
--- | ---
`geneve_ilb_addresses` | Map of VM-Series instance key => internal IP address of the per-zone GENEVE ILB forwarding rule.
`linux_vm_ips` | Map of Linux VM key => internal IP address (populated only when linux_vms is configured).
`ncc_hub_id` | Full resource ID of the NCC hub (null when enable_ncc = false).
`ncc_spoke_names` | Map of consumer VPC key => NCC spoke resource name (empty when enable_ncc = false).
`nsi_deployment_group_id` | Full resource ID of the NSI intercept deployment group.
`nsi_endpoint_group_id` | Full resource ID of the NSI intercept endpoint group.
`nsi_security_profile_group_id` | Full resource ID of the NSI security profile group.
`vmseries_private_ips` | Map of VM-Series instance key => map of NIC index => private IP address.
`vmseries_public_ips` | Map of VM-Series instance key => map of NIC index => public IP address (null when not created).

### Required Inputs details

#### consumer_vpcs

Map of consumer/spoke VPC key => VPC and subnet configuration. Each entry gets one NCC spoke and one NSI endpoint-group association.

Type: 

```hcl
map(object({
    name            = string
    subnetwork_name = string
    ip_cidr_range   = string
    firewall_rules = optional(map(object({
      name             = string
      source_ranges    = optional(list(string))
      source_tags      = optional(list(string))
      allowed_protocol = string
      allowed_ports    = optional(list(string), [])
      priority         = optional(number, 1000)
    })), {})
    firewall_policy_rules = optional(list(object({
      priority    = number
      direction   = string
      description = optional(string, "")
      match = object({
        src_ip_ranges  = optional(list(string), [])
        dest_ip_ranges = optional(list(string), [])
        layer4_configs = list(object({
          ip_protocol = string
          ports       = optional(list(string), [])
        }))
      })
    })), null)
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>

#### data_vpc

Data/GENEVE VPC for VM-Series NIC1. The GENEVE ILB and NSI intercept deployment group live here.

Type: 

```hcl
object({
    name            = string
    subnetwork_name = string
    ip_cidr_range   = string
    firewall_rules = optional(map(object({
      name             = string
      source_ranges    = optional(list(string))
      source_tags      = optional(list(string))
      allowed_protocol = string
      allowed_ports    = optional(list(string), [])
      priority         = optional(number, 1000)
    })), {})
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

#### mgmt_vpc

Management VPC for VM-Series NIC0. Kept separate from data_vpc so GCP health checks target NIC1.

Type: 

```hcl
object({
    name            = string
    subnetwork_name = string
    ip_cidr_range   = string
    firewall_rules = optional(map(object({
      name             = string
      source_ranges    = optional(list(string))
      source_tags      = optional(list(string))
      allowed_protocol = string
      allowed_ports    = optional(list(string), [])
      priority         = optional(number, 1000)
    })), {})
  })
```


<sup>[back to list](#modules-required-inputs)</sup>

#### name_prefix

Short prefix applied to every resource name (e.g. "pan-nsi-").

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### project

GCP project ID for all resources.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### region

GCP region for subnets, ILBs, and Cloud Router.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### ssh_keys

SSH public key(s) for instance-level access (format: "user:ssh-ed25519 AAAA... user@host").

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### vmseries

Map of VM-Series instance key => zone and per-instance bootstrap overrides.
Typically two entries (one per zone) for zone-redundant active-active deployment.
The module forces `plugin-op-commands = "geneve-inspect:enable"` in the merged
bootstrap_options regardless of what is set here.
Each entry must use a unique zone — NSI requires one ILB forwarding rule per zone,
and the example maps zone => forwarding rule one-to-one.


Type: 

```hcl
map(object({
    zone              = string
    bootstrap_options = optional(map(string), {})
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>

#### vmseries_image

Full VM-Series image name. Must be PAN-OS >= 11.2 for NSI GENEVE support (e.g. "vmseries-flex-byol-1120").

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### create_mgmt_public_ip

Assign a public IP to the mgmt NIC. Set true in lab environments for direct SSH/HTTPS access.

Type: bool

Default value: `false`

<sup>[back to list](#modules-optional-inputs)</sup>

#### enable_ncc

Deploy a Network Connectivity Center hub and attach each consumer VPC as a spoke. When true, all consumer VPCs gain transitive (MESH) routing through the hub, which NSI then inspects. Set false to skip NCC entirely and manage connectivity separately.

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### firewall_policy_rules

Firewall policy rules applied to each consumer VPC. The nsi_intercept module sets action=apply_security_profile_group automatically.

Type: 

```hcl
list(object({
    priority    = number
    direction   = string
    description = optional(string, "")
    match = object({
      src_ip_ranges  = optional(list(string), [])
      dest_ip_ranges = optional(list(string), [])
      layer4_configs = list(object({
        ip_protocol = string
        ports       = optional(list(string), [])
      }))
    })
  }))
```


Default value: `[map[description:Intercept all egress for PAN-OS inspection direction:EGRESS match:map[dest_ip_ranges:[0.0.0.0/0] layer4_configs:[map[ip_protocol:all]]] priority:1000] map[description:Intercept all ingress for PAN-OS inspection direction:INGRESS match:map[layer4_configs:[map[ip_protocol:all]] src_ip_ranges:[0.0.0.0/0]] priority:1001]]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### linux_vms

Optional Linux test VMs to deploy in consumer VPCs for validating NSI traffic interception end-to-end.

Type: 

```hcl
map(object({
    zone                    = string
    consumer_vpc_key        = string
    machine_type            = optional(string, "e2-micro")
    disk_size_gb            = optional(number, 20)
    metadata_startup_script = optional(string, null)
  }))
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### ncc_topology

NCC hub preset topology. MESH allows all spokes to reach each other; STAR requires designating center spokes.

Type: string

Default value: `MESH`

<sup>[back to list](#modules-optional-inputs)</sup>

#### service_account

Service account configuration for the VM-Series instances.

Type: 

```hcl
object({
    service_account_id = string
    roles              = list(string)
  })
```


Default value: `map[roles:[roles/compute.networkViewer roles/logging.logWriter roles/monitoring.metricWriter roles/monitoring.viewer roles/stackdriver.accounts.viewer roles/stackdriver.resourceMetadata.writer] service_account_id:sa-ngfw-vmseries]`

<sup>[back to list](#modules-optional-inputs)</sup>

#### vmseries_common

Common settings shared across all VM-Series instances.
The bootstrap option `plugin-op-commands = "geneve-inspect:enable"` is always
merged in automatically — do not include it here as it would be overwritten.


Type: 

```hcl
object({
    machine_type     = optional(string, "n2-standard-8")
    min_cpu_platform = optional(string, "Intel Cascade Lake")
    bootstrap_options = optional(map(string), {
      type                        = "dhcp-client"
      dhcp-send-client-id         = "yes"
      dhcp-accept-server-hostname = "yes"
      dhcp-accept-server-domain   = "yes"
      dns-primary                 = "169.254.169.254"
      panorama-server             = ""
    })
  })
```


Default value: `map[]`

<sup>[back to list](#modules-optional-inputs)</sup>
