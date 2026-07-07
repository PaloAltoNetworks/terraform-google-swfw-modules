# Palo Alto Networks Network Connectivity Center (NCC) module

This module creates a Google Cloud **Network Connectivity Center (NCC)** hub and attaches VPC spokes to it, providing transitive hub-and-spoke connectivity between workload VPCs without requiring explicit VPC peerings between each pair.

## Use with NSI

When combined with the `nsi_intercept` module, NCC provides the data path that NSI inspects. The NCC hub routes traffic between consumer (spoke) VPCs; the NSI firewall policies steer that inter-spoke traffic through the VM-Series fleet for deep-packet inspection. This pattern enables centralized security across all spoke-to-spoke and spoke-to-internet traffic flows.

## Topology

The `topology` variable controls how spokes exchange routes:

- **`MESH`** (default) — all spokes can reach all other spokes through the hub. Traffic between any two consumer VPCs is routed via NCC and can be intercepted by NSI.
- **`STAR`** — designate some spokes as "center" and others as "edge"; only center↔edge traffic is transitive. Not used by default in this module.

## Excluding ranges from export

`vpc_spokes[<key>].exclude_export_ranges` takes a list of CIDR prefixes that should **not** be advertised from that spoke to the hub. Use this to prevent hub-to-spoke route loops or to suppress private service access ranges (e.g., `199.36.153.4/30`).

## Bringing an existing hub

Set `create_hub = false` and supply `existing_hub_id` (format: `projects/<project>/locations/global/hubs/<name>`) to attach spokes to a pre-existing hub. This is useful in multi-tenant deployments where the hub is managed centrally and spokes are added per workload team.

## Reference

### Requirements

- `terraform`, version: >= 1.3, < 2.0
- `google`, version: >= 5.0

### Providers

- `google`, version: >= 5.0



### Resources

- `network_connectivity_hub` (managed)
- `network_connectivity_spoke` (managed)

### Required Inputs

Name | Type | Description
--- | --- | ---
[`name_prefix`](#name_prefix) | `string` | Short prefix applied to every resource name.
[`project_id`](#project_id) | `string` | GCP project ID where the NCC hub will be created.
[`vpc_spokes`](#vpc_spokes) | `map` | Map of spoke-key => { vpc_self_link, exclude_export_ranges }.

### Optional Inputs

Name | Type | Description
--- | --- | ---
[`create_hub`](#create_hub) | `bool` | Create the NCC hub.
[`existing_hub_id`](#existing_hub_id) | `string` | Full resource ID of an existing NCC hub (projects/.
[`hub_name`](#hub_name) | `string` | Name for the NCC hub.
[`topology`](#topology) | `string` | NCC hub preset topology: MESH (all spokes can reach all other spokes) or STAR.

### Outputs

Name |  Description
--- | ---
`hub_id` | Full resource ID of the NCC hub (created or pre-existing).
`hub_name` | Name of the NCC hub.
`spoke_ids` | Map of spoke-key => spoke full resource ID.
`spoke_names` | Map of spoke-key => spoke resource name.

### Required Inputs details

#### name_prefix

Short prefix applied to every resource name.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### project_id

GCP project ID where the NCC hub will be created.

Type: string

<sup>[back to list](#modules-required-inputs)</sup>

#### vpc_spokes

Map of spoke-key => { vpc_self_link, exclude_export_ranges }. One VPC spoke per consumer VPC.

Type: 

```hcl
map(object({
    vpc_self_link         = string
    exclude_export_ranges = optional(list(string), [])
  }))
```


<sup>[back to list](#modules-required-inputs)</sup>

### Optional Inputs details

#### create_hub

Create the NCC hub. Set false to attach spokes to an existing hub (supply existing_hub_id).

Type: bool

Default value: `true`

<sup>[back to list](#modules-optional-inputs)</sup>

#### existing_hub_id

Full resource ID of an existing NCC hub (projects/.../locations/global/hubs/...). Required when create_hub = false.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### hub_name

Name for the NCC hub. Defaults to "<name_prefix>ncc-hub" when null.

Type: string

Default value: `&{}`

<sup>[back to list](#modules-optional-inputs)</sup>

#### topology

NCC hub preset topology: MESH (all spokes can reach all other spokes) or STAR.

Type: string

Default value: `MESH`

<sup>[back to list](#modules-optional-inputs)</sup>
