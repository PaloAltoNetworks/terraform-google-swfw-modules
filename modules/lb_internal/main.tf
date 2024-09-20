resource "google_compute_health_check" "this" {
  name    = "${var.name}-${var.region}-check-tcp${var.health_check_port}"
  project = var.project

  tcp_health_check {
    port = var.health_check_port
  }
}

resource "google_compute_region_backend_service" "this" {
  provider = google-beta

  name    = var.name
  network = var.network
  project = var.project
  region  = var.region

  health_checks                   = [var.health_check != null ? var.health_check : google_compute_health_check.this.self_link]
  session_affinity                = var.session_affinity
  timeout_sec                     = var.timeout_sec
  connection_draining_timeout_sec = var.connection_draining_timeout_sec

  dynamic "backend" {
    for_each = var.backends
    content {
      group          = backend.value
      failover       = false
      balancing_mode = "CONNECTION"
    }
  }

  dynamic "backend" {
    for_each = var.failover_backends
    content {
      group          = backend.value
      failover       = true
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

  dynamic "failover_policy" {
    for_each = var.disable_connection_drain_on_failover != null || var.drop_traffic_if_unhealthy != null || var.failover_ratio != null ? ["one"] : []

    content {
      disable_connection_drain_on_failover = var.disable_connection_drain_on_failover
      drop_traffic_if_unhealthy            = var.drop_traffic_if_unhealthy
      failover_ratio                       = var.failover_ratio
    }
  }

  lifecycle {
    # For provider >=v6 `iap { enabled = false }` block is required for convergence.
    # For provider <=v5 `iap { enabled = false }` is not complete (has missing arguments).
    # To overcome issues we are ignore `iap { }` block.
    ignore_changes = [iap]
    
    create_before_destroy = true
  }
}

resource "google_compute_forwarding_rule" "this" {
  name    = var.name
  project = var.project
  region  = var.region

  load_balancing_scheme = "INTERNAL"
  ip_version            = var.ip_version
  ip_address            = var.ip_address
  ip_protocol           = var.ip_protocol
  all_ports             = var.all_ports
  ports                 = var.ports
  subnetwork            = var.subnetwork
  allow_global_access   = var.allow_global_access
  backend_service       = google_compute_region_backend_service.this.self_link
}
