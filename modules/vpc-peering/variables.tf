variable "local_network" {
  description = "Self-link or id of the first network (local) in pair."
  type        = string
}

variable "peer_network" {
  description = "Self-link or id of the second network (peer) in pair."
  type        = string
}

variable "local_peering_name" {
  description = "Name for 'local->peer' direction peering resource. If not specified defaults to `<name_prefix><local network name>-<peer network name>`."
  default     = null
  type        = string
}

variable "peer_peering_name" {
  description = "Name for 'peer->local' direction peering resource. If not specified defaults to `<name_prefix><peer network name>-<local network name>`."
  default     = null
  type        = string
}

variable "name_prefix" {
  description = "Optional prefix for auto-generated peering resource names."
  default     = ""
  type        = string
}

variable "stack_type" {
  description = "Which IP version(s) or routes are allowed to be imported or exported between peer networks. Possible values: `IPV4_ONLY` (default), `IPV4_IPV6`."
  default     = null
  type        = string
}

variable "local_export_custom_routes" {
  description = "Export custom routes setting for 'local->peer' direction."
  default     = false
  type        = bool
}

variable "local_import_custom_routes" {
  description = "Import custom routes setting for 'local->peer' direction."
  default     = false
  type        = bool
}

variable "local_export_subnet_routes_with_public_ip" {
  description = "Export subnet routes with public IP setting for 'local->peer' direction."
  default     = false
  type        = bool
}

variable "local_import_subnet_routes_with_public_ip" {
  description = "Import subnet routes with public IP setting for 'local->peer' direction."
  default     = false
  type        = bool
}

variable "peer_export_custom_routes" {
  description = "Export custom routes setting for 'peer->local' direction."
  default     = false
  type        = bool
}

variable "peer_import_custom_routes" {
  description = "Import custom routes setting for 'peer->local' direction."
  default     = false
  type        = bool
}

variable "peer_export_subnet_routes_with_public_ip" {
  description = "Export subnet routes with public IP setting for 'peer->local' direction."
  default     = false
  type        = bool
}

variable "peer_import_subnet_routes_with_public_ip" {
  description = "Import subnet routes with public IP setting for 'peer->local' direction."
  default     = false
  type        = bool
}
