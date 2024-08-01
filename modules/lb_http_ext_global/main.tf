locals {
  ipv4       = contains(["", "IPV4", "IPV4_IPV6"], var.ip_version)
  ipv4_http  = local.ipv4 && var.http_forward ? true : false
  ipv4_https = local.ipv4 && var.ssl ? true : false
  ipv6       = contains(["IPV6", "IPV4_IPV6"], var.ip_version)
  ipv6_http  = local.ipv6 && var.http_forward ? true : false
  ipv6_https = local.ipv6 && var.ssl ? true : false
}

resource "google_compute_global_forwarding_rule" "http" {
  count      = local.ipv4_http ? 1 : 0
  name       = "${var.name}-http"
  target     = google_compute_target_http_proxy.default[0].self_link
  ip_address = google_compute_global_address.default[0].address
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "http_v6" {
  count      = local.ipv6_http ? 1 : 0
  name       = "${var.name}-http-v6"
  target     = google_compute_target_http_proxy.default[0].self_link
  ip_address = google_compute_global_address.default_v6[0].address
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "https" {
  count      = local.ipv4_https ? 1 : 0
  name       = "${var.name}-https"
  target     = google_compute_target_https_proxy.default[0].self_link
  ip_address = google_compute_global_address.default[0].address
  port_range = "443"
}

resource "google_compute_global_forwarding_rule" "https_v6" {
  count      = local.ipv6_https ? 1 : 0
  name       = "${var.name}-https-v6"
  target     = google_compute_target_https_proxy.default[0].self_link
  ip_address = google_compute_global_address.default_v6[0].address
  port_range = "443"
}

moved {
  from = google_compute_global_address.default
  to   = google_compute_global_address.default[0]
}

resource "google_compute_global_address" "default" {
  count      = local.ipv4 ? 1 : 0
  name       = "${var.name}-address"
  ip_version = "IPV4"
}

resource "google_compute_global_address" "ipv6" {
  count      = local.ipv6 ? 1 : 0
  name       = "${var.name}-address-v6"
  ip_version = "IPV6"
}

# HTTP proxy when ssl is false
resource "google_compute_target_http_proxy" "default" {
  count   = var.http_forward ? 1 : 0
  name    = "${var.name}-http-proxy"
  url_map = (var.url_map != null ? var.url_map : google_compute_url_map.default.self_link)
}

# HTTPS proxy when ssl is true
resource "google_compute_target_https_proxy" "default" {
  count            = var.ssl ? 1 : 0
  name             = "${var.name}-https-proxy"
  url_map          = (var.url_map != null ? var.url_map : google_compute_url_map.default.self_link)
  ssl_certificates = compact(concat(var.ssl_certificates, google_compute_ssl_certificate.default[*].self_link, ), )
}

resource "google_compute_ssl_certificate" "default" {
  count       = var.ssl && !var.use_ssl_certificates ? 1 : 0
  name_prefix = "${var.name}-certificate"
  private_key = var.private_key
  certificate = var.certificate

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_url_map" "default" {
  name            = var.name
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_backend_service" "default" {
  name                   = var.name
  port_name              = var.backend_port_name
  protocol               = var.backend_protocol
  custom_request_headers = var.custom_request_headers
  timeout_sec            = var.timeout_sec
  dynamic "backend" {
    for_each = var.backend_groups
    content {
      group                        = backend.value
      balancing_mode               = var.balancing_mode
      capacity_scaler              = var.capacity_scaler
      max_connections_per_instance = var.max_connections_per_instance
      max_rate_per_instance        = var.max_rate_per_instance
      max_utilization              = var.max_utilization
    }
  }
  health_checks   = [google_compute_health_check.default.self_link]
  security_policy = var.security_policy
  enable_cdn      = var.cdn
}

resource "google_compute_health_check" "default" {
  name = coalesce(var.health_check_name, "${var.name}-healthcheck")
  tcp_health_check {
    port = var.health_check_port
  }
}
