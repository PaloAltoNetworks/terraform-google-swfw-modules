project     = "<PROJECT_ID>"
name_prefix = ""

networks = {
  "vmseries-vpc" = {
    vpc_name                        = "firewall-vpc"
    create_network                  = true
    delete_default_routes_on_create = false
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      "vmseries-sub" = {
        name              = "vmseries-subnet"
        create_subnetwork = true
        ip_cidr_range     = "10.10.10.0/24"
        region            = "us-central1"
      }
    }
    firewall_rules = {
      "allow-vmseries-ingress" = {
        name             = "vmseries-mgmt"
        source_ranges    = ["1.1.1.1/32"] # Replace 1.1.1.1/32 with your own souurce IP address for management purposes.
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
    }
  }
}

vmseries = {
  "fw-vmseries-01" = {
    name             = "fw-vmseries-01"
    zone             = "us-central1-b"
    vmseries_image   = "vmseries-flex-byol-1029h1"
    ssh_keys         = "admin:<YOUR_SSH_KEY>"
    machine_type     = "n2-standard-4"
    min_cpu_platform = "Intel Cascade Lake"
    tags             = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_options = {
      panorama-server = "1.1.1.1" # Modify this value as per deployment requirements
      dns-primary     = "8.8.8.8" # Modify this value as per deployment requirements
      dns-secondary   = "8.8.4.4" # Modify this value as per deployment requirements
    }
    named_ports = [
      {
        name = "http"
        port = 80
      },
      {
        name = "https"
        port = 443
      }
    ]
    network_interfaces = [
      {
        vpc_network_key  = "vmseries-vpc"
        subnetwork_key   = "vmseries-sub"
        private_ip       = "10.10.10.2"
        create_public_ip = true
      }
    ]
  }
}