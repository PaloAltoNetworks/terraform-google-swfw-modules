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
        source_ranges    = ["1.1.1.1/32"] # Set your own management source IP range.
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
    vmseries_image   = "vmseries-flex-byol-10210h9"
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
      # TODO: Modify the values below as per deployment requirements
      type                        = "dhcp-client"
      dhcp-accept-server-hostname = "yes"
      dhcp-accept-server-domain   = "yes"
      dhcp-send-hostname          = "yes"
      dhcp-send-client-id         = "yes"
      dns-primary                 = "8.8.8.8"
      dns-secondary               = "8.8.4.4"

      ## Uncomment for Panorama based bootstrap.
      # panorama-server   = "1.1.1.1"
      # panorama-server-2 = "2.2.2.2"
      # tplname           = "example-template"
      # dgname            = "example-device-group"
      # vm-auth-key       = "example-123456789"

      ## Uncomment for SCM based bootstrap.
      # panorama-server                       = "cloud"
      # dgname                                = "example-scm-folder"
      # vm-series-auto-registration-pin-id    = "example-pin-id"
      # vm-series-auto-registration-pin-value = "example-pin-value"
      # authcode                              = "D123456"
      # plugin-op-commands                    = "advance-routing:enable"
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