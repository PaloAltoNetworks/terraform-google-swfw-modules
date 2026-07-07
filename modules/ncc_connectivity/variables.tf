variable "project_id" {
  type        = string
  description = "GCP project ID where the NCC hub will be created."
}

variable "name_prefix" {
  type        = string
  description = "Short prefix applied to every resource name."
}

variable "create_hub" {
  type        = bool
  default     = true
  description = "Create the NCC hub. Set false to attach spokes to an existing hub (supply existing_hub_id)."
}

variable "hub_name" {
  type        = string
  default     = null
  description = "Name for the NCC hub. Defaults to \"<name_prefix>ncc-hub\" when null."
}

variable "existing_hub_id" {
  type        = string
  default     = null
  description = "Full resource ID of an existing NCC hub (projects/.../locations/global/hubs/...). Required when create_hub = false."
}

variable "topology" {
  type        = string
  default     = "MESH"
  description = "NCC hub preset topology: MESH (all spokes can reach all other spokes) or STAR."

  validation {
    condition     = contains(["MESH", "STAR"], var.topology)
    error_message = "topology must be MESH or STAR."
  }
}

variable "vpc_spokes" {
  type = map(object({
    vpc_self_link         = string
    exclude_export_ranges = optional(list(string), [])
  }))
  description = "Map of spoke-key => { vpc_self_link, exclude_export_ranges }. One VPC spoke per consumer VPC."
}
