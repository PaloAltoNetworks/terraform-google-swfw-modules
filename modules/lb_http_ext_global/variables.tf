variable "ip_version" {
  description = "IP version for the Global address (IPv4 or v6) - Empty defaults to IPV4"
  type        = string
  default     = ""
}

variable "name" {
  description = "Name for the forwarding rule and prefix for supporting resources"
  type        = string
}

variable "backend_groups" {
  description = "The map containing the names of instance groups (IGs) or network endpoint groups (NEGs) to serve. The IGs can be managed or unmanaged or a mix of both. All IGs must handle named port `backend_port_name`. The NEGs just handle unnamed port."
  default     = {}
  type        = map(string)
}

variable "backend_port_name" {
  description = "The port_name of the backend groups that this load balancer will serve (default is 'http')"
  default     = "http"
  type        = string
}

variable "backend_protocol" {
  description = "The protocol used to talk to the backend service"
  default     = "HTTP"
  type        = string
}

variable "health_check_name" {
  description = "Name for the health check. If not provided, defaults to `<var.name>-healthcheck`."
  default     = null
  type        = string
}

variable "health_check_port" {
  description = "TCP port to use for health check."
  default     = 80
  type        = number
}

variable "timeout_sec" {
  description = "Timeout to consider a connection dead, in seconds (default 30)"
  default     = null
  type        = number
}

variable "balancing_mode" {
  description = ""
  default     = "RATE"
  type        = string
}

variable "capacity_scaler" {
  description = ""
  default     = null
  type        = number
}

variable "max_connections_per_instance" {
  description = ""
  default     = null
  type        = number
}

variable "max_rate_per_instance" {
  description = ""
  default     = null
  type        = number
}

variable "max_utilization" {
  description = ""
  default     = null
  type        = number
}

variable "url_map" {
  description = "The url_map resource to use. Default is to send all traffic to first backend."
  type        = string
  default     = null
}

variable "http_forward" {
  description = "Set to `false` to disable HTTP port 80 forward"
  type        = bool
  default     = true
}

variable "custom_request_headers" {
  type        = list(string)
  default     = []
  description = "(Optional) Headers that the HTTP/S load balancer should add to proxied responses."
}
variable "ssl" {
  description = "Set to `true` to enable SSL support, requires variable `ssl_certificates` - a list of self_link certs"
  type        = bool
  default     = false
}

variable "private_key" {
  description = "Content of the private SSL key. Required if `ssl` is `true` and `ssl_certificates` is empty."
  type        = string
  default     = ""
}

variable "certificate" {
  description = "Content of the SSL certificate. Required if `ssl` is `true` and `ssl_certificates` is empty."
  type        = string
  default     = ""
}

variable "use_ssl_certificates" {
  description = "If true, use the certificates provided by `ssl_certificates`, otherwise, create cert from `private_key` and `certificate`"
  type        = bool
  default     = false
}

variable "ssl_certificates" {
  description = "SSL cert self_link list. Required if `ssl` is `true` and no `private_key` and `certificate` is provided."
  type        = list(string)
  default     = []
}

variable "security_policy" {
  description = "The resource URL for the security policy to associate with the backend service"
  type        = string
  default     = ""
}

variable "cdn" {
  description = "Set to `true` to enable cdn on backend."
  type        = bool
  default     = false
}
