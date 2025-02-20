variable "name" {
  description = "Name of the VM-Series instance."
  type        = string
}

variable "project" {
  description = "The ID of the project in which the resource belongs. If it is not provided, the provider project is used"
  default     = null
  type        = string
}

variable "zone" {
  description = "Zone to deploy instance in."
  type        = string
}

variable "network_interfaces" {
  description = <<-EOF
  List of the network interface specifications.
  Available options:
  - `subnetwork`                  - (Required|string) Self-link of a subnetwork to create interface in.
  - `stack_type`                  - (Optional|string) IP stack to use: IPV4_ONLY (default) or IPV4_IPV6.
  - `private_ip_name`             - (Optional|string) Name for a private IPv4 address to reserve.
  - `private_ip`                  - (Optional|string) Private IPv4 address to reserve.
  - `create_public_ip`            - (Optional|boolean) Whether to reserve public IPv4 address for the interface. Ignored if `public_ip` is provided. Defaults to 'false'.
  - `public_ip_name`              - (Optional|string) Name for a public IPv4 address to reserve.
  - `public_ip`                   - (Optional|string) Existing public IPv4 address to use.
  - `public_ptr_domain_name`      - (Optional|string) Existing public IPv4 address PTR name to use.
  - `alias_ip_ranges`             - (Optional|list) List of objects that define additional IP ranges for an interface, as specified [here](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#ip_cidr_range)
  - `create_public_ipv6`          - (Optional|boolean) Whether to reserve public IPv6 address for the interface. Ignored if `public_ipv6` is provided. Defaults to 'false'.
  - `private_ipv6_name`           - (Optional|string) Name for a private IPv6 address to reserve. Is relevant when a VPC has IPv6 ULA range.
  - `create_private_ipv6`         - (Optional|boolean) Whether to reserve private IPv6 address for the interface. Is relevant when a VPC has IPv6 ULA range. If 'false' an ephemeral IPv6 address is assigned to the interface. Default is 'true'.
  - `public_ipv6_name`            - (Optional|string) Name for a public IPv6 address to reserve.
  - `public_ipv6`                 - (Optional|string) Existing public IPv6 address to use. Specify address with a netmask, for example: 2600:1900:4020:bd2:8000:1::/96.
  - `public_ipv6_ptr_domain_name` - (Optional|string) Existing public IPv6 address PTR name to use.
  EOF
  type = list(
    object(
      {
        subnetwork             = string
        stack_type             = optional(string, "IPV4_ONLY")
        private_ip_name        = optional(string)
        private_ip             = optional(string)
        create_public_ip       = optional(bool, false)
        public_ip_name         = optional(string)
        public_ip              = optional(string)
        public_ptr_domain_name = optional(string)
        alias_ip_ranges = optional(
          list(
            object(
              {
                ip_cidr_range         = string
                subnetwork_range_name = string
              }
            )
          )
        )
        create_public_ipv6          = optional(bool, false)
        private_ipv6_name           = optional(string)
        create_private_ipv6         = optional(bool, false)
        public_ipv6_name            = optional(string)
        public_ipv6                 = optional(string)
        public_ipv6_ptr_domain_name = optional(string)
      }
    )
  )
}

variable "bootstrap_options" {
  description = <<-EOF
  VM-Series bootstrap options to pass using instance metadata.

  Proper syntax is a map, where keys are the bootstrap parameters.
  Example:
    bootstrap_options = {
      type            = dhcp-client
      panorama-server = 1.2.3.4
    }

  A list of available parameters: type, ip-address, default-gateway, netmask, ipv6-address, ipv6-default-gateway, hostname, panorama-server, panorama-server-2, tplname, dgname, dns-primary, dns-secondary, vm-auth-key, op-command-modes, op-cmd-dpdk-pkt-io, plugin-op-commands, dhcp-send-hostname, dhcp-send-client-id, dhcp-accept-server-hostname, dhcp-accept-server-domain, vm-series-auto-registration-pin-id, vm-series-auto-registration-pin-value, auth-key, authcodes, vmseries-bootstrap-gce-storagebucket, mgmt-interface-swap.

  For more details on the options please refer to [VM-Series documentation](https://docs.paloaltonetworks.com/vm-series/10-2/vm-series-deployment/bootstrap-the-vm-series-firewall/create-the-init-cfgtxt-file/init-cfgtxt-file-components).
  EOF
  default     = {}
  type        = map(string)
}

variable "ssh_keys" {
  description = "Public keys to allow SSH access for, separated by newlines."
  default     = null
  type        = string
}

variable "metadata" {
  description = "Other, not VM-Series specific, metadata to set for an instance."
  default     = {}
  type        = map(string)
}

variable "metadata_startup_script" {
  description = "See the [Terraform manual](https://www.terraform.io/docs/providers/google/r/compute_instance.html)"
  default     = null
  type        = string
}

variable "create_instance_group" {
  description = "Create an instance group, that can be used in a load balancer setup."
  default     = false
  type        = bool
}

variable "named_ports" {
  description = <<-EOF
  The list of named ports to create in the instance group:

  ```
  named_ports = [
    {
      name = "http"
      port = "80"
    },
    {
      name = "app42"
      port = "4242"
    },
  ]
  ```

  The name identifies the backend port to receive the traffic from the global load balancers.
  Practically, tcp port 80 named "http" works even when not defined here, but it's not a documented provider's behavior.
  EOF
  default     = []
  type = list(
    object(
      {
        name = string
        port = string
      }
    )
  )
}

variable "service_account" {
  description = "IAM Service Account for running firewall instance (just the email)"
  default     = null
  type        = string
}

variable "scopes" {
  description = "A list of service scopes. Both OAuth2 URLs and gcloud short names are supported. To allow full access to all Cloud APIs, use the cloud-platform scope. Defaults to the necessary VMSeries needed GCP APIs"
  default = [
    "https://www.googleapis.com/auth/compute.readonly",
    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
  type = list(string)
}

variable "vmseries_image" {
  description = <<EOF
  The image name from which to boot an instance, including a license type (bundle/flex) and version.
  To get a list of available official images, please run the following command:
  `gcloud compute images list --filter="family ~ vmseries" --project paloaltonetworksgcp-public --no-standard-images`
  EOF
  default     = "vmseries-flex-byol-10210h9"
  type        = string
}

variable "custom_image" {
  description = <<EOF
  The full URI of GCE image resource, as returned in the output of a following command:
  `gcloud compute images list --filter="<filter>" --project <project>  --no-standard-images --uri`
  Overrides official image specified using `vmseries_image`."
 EOF
  default     = null
  type        = string
}

variable "machine_type" {
  description = "Firewall instance machine type, which depends on the license used. See the [Terraform manual](https://www.terraform.io/docs/providers/google/r/compute_instance.html)"
  default     = "n2-standard-4"
  type        = string
}

variable "min_cpu_platform" {
  description = "Minimum CPU platform for the compute instance. Up to date version can be found [here](https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform)."
  default     = "Intel Cascade Lake"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection on the instance."
  default     = false
  type        = bool
}

variable "disk_type" {
  description = "Boot disk type. See [provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#type) for available values."
  default     = "pd-standard"
  type        = string
}

variable "labels" {
  description = "GCP instance lables."
  default     = {}
  type        = map(string)
}

variable "tags" {
  description = "GCP instance tags."
  default     = []
  type        = list(string)
}

variable "resource_policies" {
  default = []
  type    = list(string)
}

variable "dependencies" {
  default = []
  type    = list(string)
}
