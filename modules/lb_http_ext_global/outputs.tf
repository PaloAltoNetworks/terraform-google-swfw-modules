output "address" {
  value = google_compute_global_address.default.address
}

output "all" {
  description = "Intended mainly for `depends_on` but currently succeeds prematurely (while forwarding rules and healtchecks are not yet usable)."
  value = {
    google_compute_global_forwarding_rule_http  = google_compute_global_forwarding_rule.http
    google_compute_global_forwarding_rule_https = google_compute_global_forwarding_rule.https
    google_compute_health_check                 = google_compute_health_check.default
  }
}
