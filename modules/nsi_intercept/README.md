# Palo Alto Networks VM-Series Network Security Integration (NSI) module

This module configures Google Cloud **Network Security Integration (NSI)** — a transparent, GENEVE-based traffic-interception mechanism that steers consumer VPC traffic through a producer-side VM-Series fleet without changing routes or adding peerings.

## Architecture overview

NSI uses a two-sided model:

**Producer side** (inside the security/producer VPC):

- One `intercept_deployment` per firewall zone — references the VM-Series Internal Passthrough NLB forwarding rule that listens on UDP/6081 (GENEVE port). Because `intercept_deployment` is zone-scoped, a unique forwarding rule per zone is required even when all zones share the same backend service.
- A single global `intercept_deployment_group` that aggregates all zone-level deployments for a producer VPC.
- A single global `intercept_endpoint_group` — the logical handle that consumer associations reference.
- An optional `security_profile` + `security_profile_group` — the policy object that tells GCP which endpoint group to redirect matched traffic to. Set `create_security_profile = false` and supply `existing_security_profile_group_id` to reuse an existing profile across multiple producer VPCs.

**Consumer side** (inside each workload/spoke VPC):

- One `intercept_endpoint_group_association` per consumer VPC — activates NSI interception. **Allow 5–15 minutes per VPC for this resource to reach `ACTIVE` state on first apply.**
- One global `network_firewall_policy` per consumer VPC with rules that have `action = apply_security_profile_group` — this is what actually steers the matched flows into NSI.
- A `network_firewall_policy_association` that attaches the policy to the consumer VPC.

## VM-Series requirements

- PAN-OS **≥ 11.2** for GENEVE decapsulation support.
- Bootstrap option `plugin-op-commands = "geneve-inspect:enable"` must be present in the VM-Series bootstrap metadata.
- In PAN-OS, configure a loopback interface for each ILB forwarding-rule IP with an HTTPS management profile that allows the GCP health-check source ranges:
  - `35.191.0.0/16`
  - `130.211.0.0/22`
  - `209.85.152.0/22`
  - `209.85.204.0/22`

## Cross-project consumer VPCs

When a consumer VPC lives in a different project than `var.project_id`, set `consumer_vpcs[<key>].project_id` to that VPC's project. GCP requires the `intercept_endpoint_group_association` and the `network_firewall_policy` to reside in the same project as the consumer VPC network.

## Reference

### Requirements

- `terraform`, version: >= 1.3, < 2.0
- `google`, version: >= 6.15

### Providers

- `google`, version: >= 6.15



### Resources

- `compute_network_firewall_policy` (managed)
- `compute_network_firewall_policy_association` (managed)
- `compute_network_firewall_policy_rule` (managed)
- `network_security_intercept_deployment` (managed)
- `network_security_intercept_deployment_group` (managed)
- `network_security_intercept_endpoint_group` (managed)
- `network_security_intercept_endpoint_group_association` (managed)
- `network_security_security_profile` (managed)
- `network_security_security_profile_group` (managed)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`consumer_vpcs`](#consumer_vpcs) | `map` | Consumer VPCs to protect.
[`name_prefix`](#name_prefix) | `string` | Short prefix applied to every resource name.
[`producer_vpc_self_link`](#producer_vpc_self_link) | `string` | Self-link of the producer/security VPC — used as the intercept deployment group network.
[`project_id`](#project_id) | `string` | GCP project ID where NSI resources will be created.
[`zonal_forwarding_rules`](#zonal_forwarding_rules) | `map` | Map of zone => ILB forwarding-rule self-link.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`create_security_profile`](#create_security_profile) | `bool` | Create the security_profile and security_profile_group.
[`existing_security_profile_group_id`](#existing_security_profile_group_id) | `string` | Full ID of an existing security_profile_group.
[`firewall_policy_rules`](#firewall_policy_rules) | `list` | Rules applied to each consumer VPC's global network firewall policy.

### Outputs

Name |  Description
--- | ---
`deployment_group_id` | Full resource ID of the intercept deployment group.
`endpoint_group_association_ids` | Map of consumer-vpc-key => endpoint_group_association resource ID.
`endpoint_group_id` | Full resource ID of the intercept endpoint group.
`intercept_deployment_ids` | Map of zone => zonal intercept_deployment resource ID.
`security_profile_group_id` | Full resource ID of the security_profile_group. Use to add additional firewall policy rules outside Terraform.

### Required Inputs details

#### consumer_vpcs

Consumer VPCs to protect. Map of vpc-key => { self_link, project_id, firewall_policy_rules }.
project_id must be set when the consumer VPC is in a different project than
var.project_id — GCP requires the intercept_endpoint_group_association to be
created in the same project as the consumer VPC network.
firewall_policy_rules overrides the global var.firewall_policy_rules for this specific VPC.


Type: 

```hcl
map(object({
    self_link  = string
    project_id = optional(string, null)
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

#### name_prefix

Short prefix applied to every resource name.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### producer_vpc_self_link

Self-link of the producer/security VPC — used as the intercept deployment group network.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### project_id

GCP project ID where NSI resources will be created.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### zonal_forwarding_rules

Map of zone => ILB forwarding-rule self-link. google_network_security_intercept_deployment is zone-level
(not regional), so one entry per FW zone is required. Multiple zones in the same region share the same
regional ILB forwarding rule.


Type: map(string)

<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### create_security_profile

Create the security_profile and security_profile_group. Set false to reuse an existing profile group.

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### existing_security_profile_group_id

Full ID of an existing security_profile_group. Required when create_security_profile = false.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### firewall_policy_rules

Rules applied to each consumer VPC's global network firewall policy. The module automatically sets action=apply_security_profile_group.

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


Default value: `[map[description:Intercept all egress for PAN-OS inspection direction:EGRESS match:map[dest_ip_ranges:[0.0.0.0/0] layer4_configs:[map[ip_protocol:all]] src_ip_ranges:[]] priority:1000]]`

<sup>[back to list](#modules-optional-inputs)</sup>
