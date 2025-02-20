variable "name" {
  description = "Name of the load balancer (that is, both the forwarding rule and the backend service)"
  type        = string
}

variable "project" {
  description = "The project to deploy to. If unset the default provider project is used."
  type        = string
  default     = null
}

variable "region" {
  description = "Region to create ILB in."
  type        = string
  default     = null
}

variable "health_check_port" {
  description = "(Optional) Port number for TCP healthchecking, default 22. This setting is ignored when `health_check` is provided."
  default     = 22
  type        = number
}

variable "health_check" {
  description = "(Optional) Name of either the global google_compute_health_check or google_compute_region_health_check to use. Conflicts with health_check_port."
  default     = null
  type        = string
}

variable "backends" {
  description = "Names of primary backend groups (IGs or IGMs). Typically use `module.vmseries.instance_group_self_links` here."
  type        = map(string)
}

variable "failover_backends" {
  description = "(Optional) Names of failover backend groups (IGs or IGMs). Failover groups are ignored unless the primary groups do not meet collective health threshold."
  default     = {}
  type        = map(string)
}

variable "subnetwork" {
  description = "This field identifies the subnetwork that the load balanced IP should belong to for this Forwarding Rule."
  type = string
}

variable "ip_version" {
  description = "(Optional) The IP version that will be used by this Load Balancer. Possible values are: IPV4 (default), IPV6."
  type        = string
  default     = null
}

variable "ip_address" {
  description = <<-EOF
    (Optional) An existing private IP address on which LB listens. IP version must correspond `ip_version`.
    In case of IPv6 address specify address with a netmask, for example: fd20:6db:d1b6:1000:0:1::/96.
    If empty, a new ephemeral IP address is created on the PREMIUM tier.
  EOF
  type        = string
  default     = null
}

variable "ip_protocol" {
  description = "The IP protocol for the frontend forwarding rule, valid values are TCP and UDP."
  default     = "TCP"
  type        = string
}

variable "all_ports" {
  description = "Forward all ports of the ip_protocol from the frontend to the backends. Needs to be null if `ports` are provided."
  default     = null
  type        = bool
}

variable "ports" {
  description = "Which port numbers are forwarded to the backends (up to 5 ports). Conflicts with all_ports."
  default     = []
  type        = list(number)
}

variable "network" {
  description = "This field identifies the network that the load balanced IP should belong to for this Forwarding Rule. If the subnetwork is specified, the network of the subnetwork will be used"
  type = string
  default = null
}

variable "session_affinity" {
  description = <<-EOF
  Controls distribution of new connections (or fragmented UDP packets) from clients to the backends, can influence available connection tracking configurations.
  Valid values are: NONE (default), CLIENT_IP_NO_DESTINATION, CLIENT_IP, CLIENT_IP_PROTO, CLIENT_IP_PORT_PROTO.
  EOF
  default     = null
  type        = string
}

variable "connection_tracking_policy" {
  description = <<-EOF
  Connection tracking policy settings. Following options are available:
  - `mode`                              - (Optional|string) `PER_CONNECTION` (default) or `PER_SESSION`
  - `idle_timeout_sec`                  - (Optional|number) Defaults to 600 seconds, can only be modified in specific conditions (see link below)
  - `persistence_on_unhealthy_backends` - (Optional|string) `DEFAULT_FOR_PROTOCOL` (default), `ALWAYS_PERSIST` or `NEVER_PERSIST`

  More information about supported configurations in conjunction with `session_affinity` is available in [Internal TCP/UDP Load Balancing](https://cloud.google.com/load-balancing/docs/internal#connection-tracking) documentation.
  EOF
  default     = null
  type        = map(any)
}

variable "timeout_sec" {
  description = "(Optional) How many seconds to wait for the backend before dropping the connection. Default is 30 seconds. Valid range is [1, 86400]."
  default     = null
  type        = number
}

variable "disable_connection_drain_on_failover" {
  description = "(Optional) On failover or failback, this field indicates whether connection drain will be honored. Setting this to true has the following effect: connections to the old active pool are not drained. Connections to the new active pool use the timeout of 10 min (currently fixed). Setting to false has the following effect: both old and new connections will have a drain timeout of 10 min. This can be set to true only if the protocol is TCP. The default is false."
  default     = null
  type        = bool
}

variable "drop_traffic_if_unhealthy" {
  description = "(Optional) Used only when no healthy VMs are detected in the primary and backup instance groups. When set to true, traffic is dropped. When set to false, new connections are sent across all VMs in the primary group. The default is false."
  default     = null
  type        = bool
}

variable "failover_ratio" {
  description = "(Optional) The value of the field must be in [0, 1]. If the ratio of the healthy VMs in the primary backend is at or below this number, traffic arriving at the load-balanced IP will be directed to the failover_backends. In case where 'failoverRatio' is not set or all the VMs in the backup backend are unhealthy, the traffic will be directed back to the primary backend in the `force` mode, where traffic will be spread to the healthy VMs with the best effort, or to all VMs when no VM is healthy. This field is only used with l4 load balancing."
  default     = null
  type        = number
}

variable "allow_global_access" {
  description = "(Optional) If true, clients can access ILB from all regions. By default false, only allow from the ILB's local region; useful if the ILB is a next hop of a route."
  default     = false
  type        = bool
}

variable "connection_draining_timeout_sec" {
  type        = number
  description = "(Optional) Time for which instance will be drained (not accept new connections, but still work to finish started)."
  default     = null
}