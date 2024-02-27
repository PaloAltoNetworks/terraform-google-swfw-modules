variable "region" {
  description = "Google Cloud region to deploy the resources into."
  type        = string
}

variable "zone" {
  description = "Deployment area for Google Cloud resources within a region."
  type        = string
}

variable "subnet" {
  description = "A regional resource, defining a range of IPv4 addresses. In Google Cloud, the terms subnet and subnetwork are synonymous."
  type        = string
}

variable "project" {
  description = "The ID of the project in which the resource belongs. If it is not provided, the provider project is used."
  default     = null
  type        = string
}

variable "name" {
  description = "Name of the Panorama instance."
  type        = string
  default     = "panorama"
}

variable "private_static_ip" {
  description = <<EOF
  The static private IP address for Panorama. Only IPv4 is supported. An address may only be specified for INTERNAL address types.
  The IP address must be inside the specified subnetwork, if any. Set by the API if undefined.
  EOF
  type        = string
  default     = null
}

variable "attach_public_ip" {
  description = "Determines if a Public IP should be assigned to Panorama. Set by the API if the `public_static_ip` variable is not defined."
  type        = bool
  default     = false
}

variable "public_static_ip" {
  description = "The static external IP address for Panorama instance. Only IPv4 is supported. Set by the API if undefined."
  type        = string
  default     = null
}

variable "log_disks" {
  description = <<-EOF
  List of disks to create and attach to Panorama to store traffic logs.
  Available options:
  - `name`              (Required) Name of the resource. The name must be 1-63 characters long, and comply with [`RFC1035`](https://datatracker.ietf.org/doc/html/rfc1035).
  - `type`              (Optional) Disk type resource describing which disk type to use to create the disk. For available options, check the providers [documentation](https://cloud.google.com/compute/docs/disks#disk-types).
  - `size`              (Optional) Size of the disk for Panorama logs (Gigabytes).

  Example:
  ```
  log_disks = [
    {
      name = "example-disk-1"
      type = "pd-ssd"
      size = "2000"
    },
    {
      name = "example-disk-2"
      type = "pd-ssd"
      size = "3000"
    },
  ]
  ```
  EOF
  default     = []
}

variable "machine_type" {
  description = "See the [Terraform manual](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)"
  type        = string
  default     = "n1-standard-16"
}

variable "min_cpu_platform" {
  description = "See the [Terraform manual](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)"
  type        = string
  default     = "Intel Broadwell"
}

variable "deletion_protection" {
  description = "Enable deletion protection on the instance."
  default     = false
  type        = bool
}

variable "labels" {
  description = "See the [Terraform manual](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)"
  type        = map(any)
  default     = {}
}

variable "tags" {
  description = "See the [Terraform manual](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)"
  type        = list(string)
  default     = []
}

variable "disk_type" {
  description = "Type of boot disk. For available options, check the providers [documentation](https://cloud.google.com/compute/docs/disks#disk-types)."
  type        = string
  default     = "pd-ssd"
}

variable "disk_size" {
  description = "Size of boot disk in gigabytes. Default is the same as the OS image."
  type        = string
  default     = null
}

variable "ssh_keys" {
  description = <<EOF
  In order to connect via SSH to Panorama, provide your SSH public key here.
  Remember to add the `admin` prefix before you insert your public SSH key.
  More than one key can be added.

  Example:
  `ssh_keys = "admin:ssh-rsa AAAAB4NzaC5yc9EAACABBACBgQDAcjYw6xa2zUZ6reqHqDp9bYDLTu7Rnk5Sa3hthIsIsFaKenFLe4w3mm5eF3ebsfAAnuzI9ua9g7aB/ThIsIsAlSoFaKeN2VhUMDmlBYO5m1D4ip6eugS6uM="`
  EOF
  type        = string
}

variable "panorama_version" {
  description = <<EOF
  Panorama version - based on the name of the Panorama public image - allows to specify which Panorama version will be deployed.
  For more details regarding available Panorama versions in the Google Cloud Platform, please run the following command:
  `gcloud compute images list --filter="name ~ .*panorama.*" --project paloaltonetworksgcp-public --no-standard-images`
  EOF
  type        = string
  default     = "panorama-byol-1000"
}

variable "custom_image" {
  description = <<-EOF
  Custom image for your Panorama instances. Custom images are available only to your Cloud project. 
  You can create a custom image from boot disks and other images. 
  For more information, please check the provider [documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#image)
  as well as the [Panorama Administrator's Guide](https://docs.paloaltonetworks.com/panorama/10-2/panorama-admin/set-up-panorama/set-up-the-panorama-virtual-appliance/install-the-panorama-virtual-appliance/install-panorama-on-gcp.html).
  
  If a `custom_image` is not specified, `image_project` and `image_family` are used to determine a Public image to use for Panorama.
  EOF
  type        = string
  default     = null
}

variable "metadata" {
  description = "See the [Terraform manual](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)"
  type        = map(string)
  default     = {}
}

variable "service_account" {
  description = "IAM Service Account for running Panorama instance (just the email)"
  type        = string
  default     = null
}

variable "scopes" {
  description = "Access scopes for the compute instance - both OAuth2 URLs and gcloud short names are supported"
  type        = list(string)
  default     = []
}
