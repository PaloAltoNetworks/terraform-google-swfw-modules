data "google_client_config" "this" {}

locals {
  # If we were told an exact region, use it, otherwise fall back to a client-default region
  region = coalesce(var.region, data.google_client_config.this.region)

  # Check for `L3_DEFAULT` as this requires `google_compute_region_backend_service` and `google_compute_region_health_check` resources.
  backend_service_needed = contains([for k, v in var.rules : lookup(v, "ip_protocol", null)], "L3_DEFAULT")

  # Check for protocols that require a `google_compute_target_pool` backend and `google_compute_http_health_check` health check
  target_pool_protocols = ["TCP", "UDP", "ESP", "AH", "SCTP", "ICMP"]
  target_pool_needed    = contains([for k, v in var.rules : contains(local.target_pool_protocols, lookup(v, "ip_protocol", "TCP"))], true)
}

# Create external IP addresses if non-specified
resource "google_compute_address" "this" {
  for_each = { for k, v in var.rules : k => v if !can(v.ip_address) }

  name               = each.key
  address_type       = "EXTERNAL"
  region             = var.region
  project            = var.project
  ip_version         = try(each.value.ip_version, null)
  ipv6_endpoint_type = try(each.value.ip_version, "IPV4") == "IPV6" ? "NETLB" : null
  subnetwork         = try(each.value.ip_version, "IPV4") == "IPV6" ? var.subnetwork : null
  network_tier       = var.network_tier
}

# Create forwarding rule for each specified rule
resource "google_compute_forwarding_rule" "rule" {
  for_each = var.rules

  name    = each.key
  project = var.project
  region  = local.region

  # Check if `ip_protocol` is specified (if not assume default of `TCP`) != `L3_DEFAULT` if true then use `google_compute_target_pool` as backend
  target = lookup(each.value, "ip_protocol", "TCP") != "L3_DEFAULT" ? google_compute_target_pool.this[0].self_link : null

  # Check if `ip_protocol` is specified (if not assume default of `TCP`) == `L3_DEFAULT` if true then use `google_compute_region_backend_service` as backend
  backend_service       = lookup(each.value, "ip_protocol", "TCP") == "L3_DEFAULT" ? google_compute_region_backend_service.this[0].self_link : null
  load_balancing_scheme = "EXTERNAL"

  # Check if `ip_protocol` is specified (if not assume default of `TCP`) == `L3_DEFAULT`.
  #   If true then set `all_ports` to `true`.
  #   If false set value to the value of `all_ports`. If `all_ports` isn't specified, then set the value to `null`.
  all_ports = lookup(each.value, "ip_protocol", "TCP") == "L3_DEFAULT" ? true : lookup(each.value, "all_ports", null)

  # Check if `ip_protocol` is specified (if not assume default of `TCP`) == `L3_DEFAULT`.
  #   If true then set `port_range` to `null`.
  #   If false set value to the value of `port_range`. If `port_range` isn't specified, then set the value to `null`.
  port_range = lookup(each.value, "ip_protocol", "TCP") == "L3_DEFAULT" ? null : lookup(each.value, "port_range", null)

  ip_address = try(each.value.ip_address, try(each.value.ip_version, "IPV4") == "IPV4" ? (
    google_compute_address.this[each.key].address
    ) : (
    "${google_compute_address.this[each.key].address}/${google_compute_address.this[each.key].prefix_length}"
  ))
  ip_protocol = lookup(each.value, "ip_protocol", "TCP")
  # Provider recreates resource if `ip_version` changes.
  # Use `null` as a default value to prevent existing LB re-creation when `ip_version` parameter is introduced.
  ip_version   = lookup(each.value, "ip_version", null)
  subnetwork   = lookup(each.value, "ip_version", "IPV4") == "IPV6" ? var.subnetwork : null
  network_tier = var.network_tier
}

# Create `google_compute_target_pool` if required by `var.rules`
resource "google_compute_target_pool" "this" {
  count = local.target_pool_needed ? 1 : 0

  name    = var.name
  project = var.project
  region  = local.region

  instances        = var.instances
  health_checks    = var.create_health_check ? [google_compute_http_health_check.this[0].self_link] : []
  session_affinity = var.session_affinity

  lifecycle {
    # Ignore changes because autoscaler changes this in the background.
    ignore_changes = [instances]
  }
}

# Create `google_compute_http_health_check` if required by `var.rules`
resource "google_compute_http_health_check" "this" {
  count = var.create_health_check && local.target_pool_needed ? 1 : 0

  name                = "${var.name}-${local.region}"
  check_interval_sec  = var.health_check_interval_sec
  healthy_threshold   = var.health_check_healthy_threshold
  timeout_sec         = var.health_check_timeout_sec
  unhealthy_threshold = var.health_check_unhealthy_threshold
  port                = var.health_check_http_port
  request_path        = var.health_check_http_request_path
  host                = var.health_check_http_host
  project             = var.project
}

# Create `google_compute_region_backend_service` if require by `var.rules`
resource "google_compute_region_backend_service" "this" {
  provider = google-beta

  count = local.backend_service_needed ? 1 : 0

  name    = var.name
  project = var.project
  region  = local.region

  load_balancing_scheme = "EXTERNAL"
  health_checks         = var.create_health_check ? [google_compute_region_health_check.this[0].self_link] : []
  protocol              = "UNSPECIFIED"
  session_affinity      = var.session_affinity

  dynamic "backend" {
    for_each = var.backend_instance_groups
    content {
      group          = backend.value
      balancing_mode = "CONNECTION"
    }
  }

  # This feature requires beta provider as of 2023-03-16
  dynamic "connection_tracking_policy" {
    for_each = var.connection_tracking_policy != null ? ["this"] : []
    content {
      tracking_mode                                = try(var.connection_tracking_policy.mode, null)
      idle_timeout_sec                             = try(var.connection_tracking_policy.idle_timeout_sec, null)
      connection_persistence_on_unhealthy_backends = try(var.connection_tracking_policy.persistence_on_unhealthy_backends, null)
    }
  }
}

# Create `google_compute_region_backend_service` if require by `var.rules`
resource "google_compute_region_health_check" "this" {
  count = var.create_health_check && local.backend_service_needed ? 1 : 0

  name                = "${var.name}-${local.region}"
  project             = var.project
  region              = local.region
  check_interval_sec  = var.health_check_interval_sec
  healthy_threshold   = var.health_check_healthy_threshold
  timeout_sec         = var.health_check_timeout_sec
  unhealthy_threshold = var.health_check_unhealthy_threshold

  http_health_check {
    port         = var.health_check_http_port
    request_path = var.health_check_http_request_path
    host         = var.health_check_http_host
  }
}

