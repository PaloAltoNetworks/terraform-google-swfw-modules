# General
project     = "<PROJECT_ID>" # Modify this value as per deployment requirements
region      = "us-east1"     # Modify this value as per deployment requirements
name_prefix = ""             # Modify this value as per deployment requirements

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

bootstrap_buckets = {
  vmseries-bootstrap-bucket-01 = {
    bucket_name_prefix  = "bucket-01-"
    location            = "us"
    service_account_key = "sa-vmseries-01"
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
        region            = "us-east1"
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
        region            = "us-east1"
        stack_type        = "IPV4_IPV6"
        ipv6_access_type  = "EXTERNAL"
      }
    }
    firewall_rules = {
      allow-untrust-ingress-ipv4-1 = {
        name             = "allow-untrust-vpc-ipv4-1"
        source_ranges    = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"] # Add app client IP range.
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
      allow-untrust-ingress-ipv6-1 = {
        name             = "allow-untrust-vpc-ipv6-1"
        source_ranges    = ["2600:1901:8001::/48"] # Add app client source IP range.
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
    enable_ula_internal_ipv6        = true
    subnetworks = {
      fw-trust-sub = {
        name              = "fw-trust-sub"
        create_subnetwork = true
        stack_type        = "IPV4_IPV6"
        ip_cidr_range     = "10.10.12.0/28"
        ipv6_access_type  = "INTERNAL"
        region            = "us-east1"
      }
    }
    firewall_rules = {
      allow-trust-ingress-ipv4-1 = {
        name             = "allow-trust-vpc-ipv4-1"
        source_ranges    = ["192.168.0.0/16", "130.211.0.0/22", "35.191.0.0/16"]
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
      allow-trust-ingress-ipv6-1 = {
        name             = "allow-trust-vpc-ipv6-1"
        source_ranges    = ["fd20::/20", "2600:2d00:1:b029::/64"]
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
    enable_ula_internal_ipv6        = true

    subnetworks = {
      fw-spoke1-sub = {
        name              = "fw-spoke1-sub"
        create_subnetwork = true
        stack_type        = "IPV4_IPV6"
        ip_cidr_range     = "192.168.1.0/28"
        ipv6_access_type  = "INTERNAL"
        region            = "us-east1"
      }
    }
    firewall_rules = {
      allow-spoke1-ingress-ipv4-1 = {
        name             = "allow-spoke1-vpc-ipv4-1"
        source_ranges    = ["192.168.0.0/16", "35.235.240.0/20", "10.10.12.0/28"]
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
      allow-spoke1-ingress-ipv6-1 = {
        name             = "allow-spoke1-vpc-ipv6-1"
        source_ranges    = ["fd20::/20"] # Common GCP IPv6 ULA range
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
    enable_ula_internal_ipv6        = true

    subnetworks = {
      fw-spoke2-sub = {
        name              = "fw-spoke2-sub"
        create_subnetwork = true
        stack_type        = "IPV4_IPV6"
        ip_cidr_range     = "192.168.2.0/28"
        ipv6_access_type  = "INTERNAL"
        region            = "us-east1"
      }
    }
    firewall_rules = {
      allow-spoke2-ingress-ipv4-1 = {
        name             = "allow-spoke2-vpc-ipv4-1"
        source_ranges    = ["192.168.0.0/16", "35.235.240.0/20", "10.10.12.0/28"]
        priority         = "1000"
        allowed_protocol = "all"
        allowed_ports    = []
      }
      allow-spoke2-ingress-ipv6-1 = {
        name             = "allow-spoke2-vpc-ipv6-1"
        source_ranges    = ["fd20::/20"] # Common GCP IPv6 ULA range
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
    stack_type                               = "IPV4_IPV6"
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
    stack_type                               = "IPV4_IPV6"
  }
}

# IPv4 static routes
routes = {
  fw-default-trust-ipv4 = {
    name              = "fw-default-trust-ipv4"
    destination_range = "0.0.0.0/0"
    vpc_network_key   = "fw-trust-vpc"
    lb_internal_key   = "internal-lb-ipv4"
  }
}

# IPv6 policy-based routing
policy_routes = {
  spoke1-vpc-default-ipv6 = {
    name              = "spoke1-vpc-default-ipv6"
    destination_range = "::/0"
    vpc_network_key   = "fw-spoke1-vpc"
    lb_internal_key   = "internal-lb-ipv6"
  }
  spoke2-vpc-default-ipv6 = {
    name              = "spoke2-vpc-default-ipv6"
    destination_range = "::/0"
    vpc_network_key   = "fw-spoke2-vpc"
    lb_internal_key   = "internal-lb-ipv6"
  }
}

policy_routes_trust_vpc_network_key = "fw-trust-vpc"

# VM-Series

vmseries_common = {
  ssh_keys            = "admin:<your_ssh_key>" # Modify this value as per deployment requirements
  vmseries_image      = "vmseries-flex-byol-1114h7"
  machine_type        = "n2-standard-4"
  min_cpu_platform    = "Intel Cascade Lake"
  service_account_key = "sa-vmseries-01"
  bootstrap_options = {
    # TODO: Modify the values below as per deployment requirements
    type                = "dhcp-client"
    mgmt-interface-swap = "enable"

    ## Panorama based bootstrap.
    # panorama-server   = "1.1.1.1"
    # panorama-server-2 = "2.2.2.2"
    # tplname           = "example-template"
    # dgname            = "example-device-group"
    # vm-auth-key       = "example-123456789"

    ## SCM based bootstrap.
    # panorama-server                       = "cloud"
    # dgname                                = "example-scm-folder"
    # vm-series-auto-registration-pin-id    = "example-pin-id"
    # vm-series-auto-registration-pin-value = "example-pin-value"
    # authcode                              = "D123456"
    # plugin-op-commands                    = "advance-routing:enable"
  }
}

vmseries = {
  fw-vmseries-01 = {
    name = "fw-vmseries-01"
    zone = "us-east1-b"
    tags = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
    bootstrap_options = {
      # TODO: Modify the values below as per deployment requirements
      dns-primary   = "8.8.8.8"
      dns-secondary = "8.8.4.4"
    }
    bootstrap_template_map = {
      trust_gcp_router_ip   = "10.10.12.1"
      untrust_gcp_router_ip = "10.10.11.1"
      private_network_cidr  = "192.168.0.0/16"
      untrust_loopback_ip   = "1.1.1.1/32" # This is placeholder IP - you must replace it in the VM-Series config with the External LB IPv4 address after the infrastructure is deployed
      trust_loopback_ip     = "10.10.12.5/32"
      untrust_loopback_ipv6 = "1::1/128"    # This is placeholder IP - you must replace it in the VM-Series config with the External LB IPv6 address after the infrastructure is deployed
      trust_loopback_ipv6   = "fd20::1/128" # This is placeholder IP - you must replace it in the VM-Series config with the Internal LB IPv6 address after the infrastructure is deployed
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
        vpc_network_key    = "fw-untrust-vpc"
        subnetwork_key     = "fw-untrust-sub"
        stack_type         = "IPV4_IPV6"
        private_ip         = "10.10.11.2"
        create_public_ip   = true
        create_public_ipv6 = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub"
        private_ip       = "10.10.10.2"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub"
        stack_type      = "IPV4_IPV6"
        private_ip      = "10.10.12.2"
      }
    ]
  },
  fw-vmseries-02 = {
    name = "fw-vmseries-02"
    zone = "us-east1-c"
    tags = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
    bootstrap_options = {
      # TODO: Modify the values below as per deployment requirements
      dns-primary   = "8.8.8.8"
      dns-secondary = "8.8.4.4"
    }
    bootstrap_template_map = {
      trust_gcp_router_ip   = "10.10.12.1"
      untrust_gcp_router_ip = "10.10.11.1"
      private_network_cidr  = "192.168.0.0/16"
      untrust_loopback_ip   = "1.1.1.1/32" # This is placeholder IP - you must replace it in the VM-Series config with the External LB IPv4 address after the infrastructure is deployed
      trust_loopback_ip     = "10.10.12.5/32"
      untrust_loopback_ipv6 = "1::1/128"    # This is placeholder IP - you must replace it in the VM-Series config with the External LB IPv6 address after the infrastructure is deployed
      trust_loopback_ipv6   = "fd20::1/128" # This is placeholder IP - you must replace it in the VM-Series config with the Internal LB IPv6 address after the infrastructure is deployed
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
        vpc_network_key    = "fw-untrust-vpc"
        subnetwork_key     = "fw-untrust-sub"
        stack_type         = "IPV4_IPV6"
        private_ip         = "10.10.11.3"
        create_public_ip   = true
        create_public_ipv6 = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub"
        private_ip       = "10.10.10.3"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub"
        stack_type      = "IPV4_IPV6"
        private_ip      = "10.10.12.3"
      }
    ]
  }
}

# Spoke Linux VMs
linux_vms = {
  spoke1-vm = {
    linux_machine_type = "n2-standard-4"
    zone               = "us-east1-b"
    linux_disk_size    = "50" # Modify this value as per deployment requirements
    vpc_network_key    = "fw-spoke1-vpc"
    subnetwork_key     = "fw-spoke1-sub"
    stack_type         = "IPV4_IPV6"
    private_ip         = "192.168.1.2"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    service_account_key = "sa-linux-01"
  },
  spoke2-vm = {
    linux_machine_type = "n2-standard-4"
    zone               = "us-east1-b"
    linux_disk_size    = "50" # Modify this value as per deployment requirements
    vpc_network_key    = "fw-spoke2-vpc"
    subnetwork_key     = "fw-spoke2-sub"
    stack_type         = "IPV4_IPV6"
    private_ip         = "192.168.2.2"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    service_account_key = "sa-linux-01"
  }
}

# Internal Network Loadbalancer
lbs_internal = {
  internal-lb-ipv4 = {
    name              = "internal-lb-ipv4"
    health_check_port = "80"
    backends          = ["fw-vmseries-01", "fw-vmseries-02"]
    ip_address        = "10.10.12.5"
    subnetwork        = "fw-trust-sub"
    vpc_network_key   = "fw-trust-vpc"
    subnetwork_key    = "fw-trust-sub"
    ip_version        = "IPV4"
  }
  internal-lb-ipv6 = {
    name              = "internal-lb-ipv6"
    health_check_port = "80"
    backends          = ["fw-vmseries-01", "fw-vmseries-02"]
    ip_address        = null
    subnetwork        = "fw-trust-sub"
    vpc_network_key   = "fw-trust-vpc"
    subnetwork_key    = "fw-trust-sub"
    ip_version        = "IPV6"
  }
}

# External Network Loadbalancer
lbs_external = {
  external-lb = {
    name     = "external-lb-ipv4-ipv6"
    backends = ["fw-vmseries-01", "fw-vmseries-02"]
    rules = {
      all-ports-ipv4 = {
        ip_protocol = "L3_DEFAULT"
      }
      all-ports-ipv6 = {
        ip_version  = "IPV6"
        ip_protocol = "L3_DEFAULT"
      }
    }
    vpc_network_key                = "fw-untrust-vpc"
    subnetwork_key                 = "fw-untrust-sub"
    http_health_check_port         = "80"
    http_health_check_request_path = "/unauth/php/health.php"
  }
}