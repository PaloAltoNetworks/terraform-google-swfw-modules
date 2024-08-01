output "address" {
  value = try(google_compute_global_address.ipv4[0].address, null)
}

output "address_v6" {
  value = try(google_compute_global_address.ipv6[0].address, null)
}

output "all" {
  description = "Intended mainly for `depends_on` but currently succeeds prematurely (while forwarding rules and healtchecks are not yet usable)."
  value = {
    google_compute_global_forwarding_rule_http     = google_compute_global_forwarding_rule.http
    google_compute_global_forwarding_rule_https    = google_compute_global_forwarding_rule.https
    google_compute_global_forwarding_rule_http_v6  = google_compute_global_forwarding_rule.http_v6
    google_compute_global_forwarding_rule_https_v6 = google_compute_global_forwarding_rule.https_v6
    google_compute_health_check                    = google_compute_health_check.default
  }
}
