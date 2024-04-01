output "address" {
  value = google_compute_global_address.default.address
}

output "address6" {
  value = try(google_compute_global_address.default6[0].address, null)
}

output "all" {
  description = "Intended mainly for `depends_on` but currently succeeds prematurely (while forwarding rules and healtchecks are not yet usable)."
  value = {
    google_compute_global_forwarding_rule_http   = google_compute_global_forwarding_rule.http
    google_compute_global_forwarding_rule_https  = google_compute_global_forwarding_rule.https
    google_compute_global_forwarding_rule_http6  = try(google_compute_global_forwarding_rule.http6[0], null)
    google_compute_global_forwarding_rule_https6 = try(google_compute_global_forwarding_rule.https6[0], null)
    google_compute_health_check                  = google_compute_health_check.default
  }
}
