# General
project     = "<PROJECT_ID>"
region      = "us-east4"
name_prefix = ""

# Service accounts
service_accounts = {
  sa-vmseries-01 = {
    service_account_id = "sa-vmseries-01"
    display_name       = "VM-Series SA"
    roles = [
      "roles/compute.networkViewer",
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/viewer"
    ]
  },
  sa-linux-01 = {
    service_account_id = "sa-linux-01"
    display_name       = "Linux VMs SA"
    roles = [
      "roles/compute.networkViewer",
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/viewer"
    ]
  }
}

# VPC
networks = {
  fw-mgmt-vpc = {
    vpc_name                        = "fw-mgmt-vpc"
    create_network                  = true
    delete_default_routes_on_create = false
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      fw-mgmt-sub = {
        name              = "fw-mgmt-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.10.10.0/28"
        region            = "us-east4"
      }
    }
    firewall_rules = {
      allow-mgmt-ingress = {
        name             = "allow-mgmt-ingress"
        source_ranges    = ["1.1.1.1/32"] # Set your own management source IP range.
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
    }
  },
  fw-untrust-vpc = {
    vpc_name                        = "fw-untrust-vpc"
    create_network                  = true
    delete_default_routes_on_create = false
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      fw-untrust-sub = {
        name              = "fw-untrust-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.10.11.0/28"
        region            = "us-east4"
      }
    }
    firewall_rules = {
      allow-untrust-ingress = {
        name             = "allow-untrust-vpc"
        source_ranges    = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"] # Add app client IP range.
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
    }
  },
  fw-trust-vpc = {
    vpc_name                        = "fw-trust-vpc"
    create_network                  = true
    delete_default_routes_on_create = true
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      fw-trust-sub = {
        name              = "fw-trust-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.10.12.0/28"
        region            = "us-east4"
      }
    }
    firewall_rules = {
      allow-trust-ingress = {
        name             = "allow-trust-vpc"
        source_ranges    = ["192.168.0.0/16", "35.191.0.0/16", "130.211.0.0/22"]
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
    }
  },
  fw-spoke1-vpc = {
    vpc_name                        = "fw-spoke1-vpc"
    create_network                  = true
    delete_default_routes_on_create = true
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      fw-spoke1-sub = {
        name              = "fw-spoke1-sub"
        create_subnetwork = true
        ip_cidr_range     = "192.168.1.0/28"
        region            = "us-east4"
      }
    }
    firewall_rules = {
      allow-spoke1-ingress = {
        name             = "allow-spoke1-vpc"
        source_ranges    = ["192.168.0.0/16", "35.235.240.0/20", "10.10.12.0/28"]
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
    }
  },
  fw-spoke2-vpc = {
    vpc_name                        = "fw-spoke2-vpc"
    create_network                  = true
    delete_default_routes_on_create = true
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      fw-spoke2-sub = {
        name              = "fw-spoke2-sub"
        create_subnetwork = true
        ip_cidr_range     = "192.168.2.0/28"
        region            = "us-east4"
      }
    }
    firewall_rules = {
      allow-spoke2-ingress = {
        name             = "allow-spoke2-vpc"
        source_ranges    = ["192.168.0.0/16", "35.235.240.0/20", "10.10.12.0/28"]
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
    }
  }
}

# VPC Peerings
vpc_peerings = {
  trust-to-spoke1 = {
    local_network_key = "fw-trust-vpc"
    peer_network_key  = "fw-spoke1-vpc"

    local_export_custom_routes                = true
    local_import_custom_routes                = true
    local_export_subnet_routes_with_public_ip = true
    local_import_subnet_routes_with_public_ip = true

    peer_export_custom_routes                = true
    peer_import_custom_routes                = true
    peer_export_subnet_routes_with_public_ip = true
    peer_import_subnet_routes_with_public_ip = true
  },
  trust-to-spoke2 = {
    local_network_key = "fw-trust-vpc"
    peer_network_key  = "fw-spoke2-vpc"

    local_export_custom_routes                = true
    local_import_custom_routes                = true
    local_export_subnet_routes_with_public_ip = true
    local_import_subnet_routes_with_public_ip = true

    peer_export_custom_routes                = true
    peer_import_custom_routes                = true
    peer_export_subnet_routes_with_public_ip = true
    peer_import_subnet_routes_with_public_ip = true
  }
}

# Static routes
routes = {
  fw-default-trust = {
    name              = "fw-default-trust"
    destination_range = "0.0.0.0/0"
    vpc_network_key   = "fw-trust-vpc"
    lb_internal_key   = "internal-lb"
  }
}

# Autoscale
autoscale_regional_mig = true

autoscale_common = {
  image            = "vmseries-flex-byol-1116h7"
  machine_type     = "n2-standard-4"
  min_cpu_platform = "Intel Cascade Lake"
  disk_type        = "pd-ssd"
  scopes = [
    "https://www.googleapis.com/auth/compute.readonly",
    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
  ]
  tags                             = ["vmseries-autoscale"]
  update_policy_type               = "OPPORTUNISTIC"
  cooldown_period                  = 480
  scale_in_control_time_window_sec = 1800
  scale_in_control_replicas_fixed  = 1
  autoscaler_metrics = {
    "custom.googleapis.com/VMSeries/panSessionUtilization" = {
      target = 70
      filter = "resource.type = \"gce_instance\""
    }
    "custom.googleapis.com/VMSeries/panSessionThroughputKbps" = {
      target = 700000
      filter = "resource.type = \"gce_instance\""
    }
  }
}

autoscale = {
  fw-autoscale-obew = {
    name = "fw-autoscale-obew"
    zones = {
      zone1 = "us-east4-b"
      zone2 = "us-east4-c"
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
    service_account_key   = "sa-vmseries-01"
    min_vmseries_replicas = 2
    max_vmseries_replicas = 4
    create_pubsub_topic   = true
    bootstrap_options = {
      # TODO: Modify the values below as per deployment requirements
      type                        = "dhcp-client"
      dhcp-send-hostname          = "yes"
      dhcp-send-client-id         = "yes"
      dhcp-accept-server-hostname = "yes"
      dhcp-accept-server-domain   = "yes"
      mgmt-interface-swap         = "enable"
      ssh-keys                    = "admin:<your_ssh_key>" # Replace this value with client data
      plugin-op-commands          = "advance-routing:enable"

      # Uncomment for Panorama based bootstrap.
      panorama-server   = "1.1.1.1"
      panorama-server-2 = "2.2.2.2"
      tplname           = "example-template"
      dgname            = "example-device-group"
      vm-auth-key       = "example-123456789"

      ## Uncomment for SCM based bootstrap.
      # panorama-server                       = "cloud"
      # dgname                                = "example-scm-folder"
      # vm-series-auto-registration-pin-id    = "example-pin-id"
      # vm-series-auto-registration-pin-value = "example-pin-value"
      # authcodes                             = "D123456"
    }
    network_interfaces = [
      {
        vpc_network_key  = "fw-untrust-vpc"
        subnetwork_key   = "fw-untrust-sub"
        create_public_ip = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub"
      }
    ]
  },
  fw-autoscale-inbound = {
    name = "fw-autoscale-inbound"
    zones = {
      zone1 = "us-east4-b"
      zone2 = "us-east4-c"
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
    service_account_key   = "sa-vmseries-01"
    min_vmseries_replicas = 2
    max_vmseries_replicas = 4
    create_pubsub_topic   = true
    autoscaler_metrics = {
      "custom.googleapis.com/VMSeries/panSessionUtilization" = {
        target = 65
        type   = "GAUGE"
      }
    }
    bootstrap_options = {
      type                        = "dhcp-client"
      dhcp-send-hostname          = "yes"
      dhcp-send-client-id         = "yes"
      dhcp-accept-server-hostname = "yes"
      dhcp-accept-server-domain   = "yes"
      mgmt-interface-swap         = "enable"
      panorama-server             = "1.1.1.1"
      ssh-keys                    = "admin:<your_ssh_key>" # Replace this value with client data
      plugin-op-commands          = "advance-routing:enable"
    }
    network_interfaces = [
      {
        vpc_network_key  = "fw-untrust-vpc"
        subnetwork_key   = "fw-untrust-sub"
        create_public_ip = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub"
      }
    ]
  }
}

# Spoke Linux VMs
linux_vms = {
  spoke1-vm = {
    linux_machine_type = "n2-standard-4"
    zone               = "us-east4-b"
    linux_disk_size    = "50"
    vpc_network_key    = "fw-spoke1-vpc"
    subnetwork_key     = "fw-spoke1-sub"
    private_ip         = "192.168.1.2"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    service_account_key = "sa-linux-01"
  },
  spoke2-vm = {
    linux_machine_type = "n2-standard-4"
    zone               = "us-east4-b"
    linux_disk_size    = "50"
    vpc_network_key    = "fw-spoke2-vpc"
    subnetwork_key     = "fw-spoke2-sub"
    private_ip         = "192.168.2.2"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    service_account_key = "sa-linux-01"
  }
}

# Internal Network Loadbalancer
lbs_internal = {
  internal-lb = {
    name              = "internal-lb"
    health_check_port = "80"
    backends          = ["fw-autoscale-obew"]
    subnetwork        = "fw-trust-sub"
    vpc_network_key   = "fw-trust-vpc"
    subnetwork_key    = "fw-trust-sub"
  }
}

# External Network Loadbalancer
lbs_external = {
  external-lb = {
    name     = "external-lb"
    backends = ["fw-autoscale-inbound"]
    rules = {
      all-ports = {
        ip_protocol = "L3_DEFAULT"
      }
    }
    http_health_check_port         = "80"
    http_health_check_request_path = "/php/login.php"
  }
}

