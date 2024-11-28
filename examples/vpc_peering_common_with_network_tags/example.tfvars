# General
project     = "<PROJECT_ID>"
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
      fw-mgmt-sub-region-1 = {
        name              = "fw-mgmt-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.10.10.0/28"
        region            = "us-east1"
      },
      fw-mgmt-sub-region-2 = {
        name              = "fw-mgmt-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.20.10.0/28"
        region            = "us-west1"
      }
    }
    firewall_rules = {
      allow-mgmt-ingress = {
        name             = "allow-mgmt-vpc"
        source_ranges    = ["10.10.10.0/28", "10.20.10.0/28"] # Set your own management source IP range.
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
      fw-untrust-sub-region-1 = {
        name              = "fw-untrust-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.10.11.0/28"
        region            = "us-east1"
      },
      fw-untrust-sub-region-2 = {
        name              = "fw-untrust-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.20.11.0/28"
        region            = "us-west1"
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
      fw-trust-sub-region-1 = {
        name              = "fw-trust-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.10.12.0/28"
        region            = "us-east1"
      },
      fw-trust-sub-region-2 = {
        name              = "fw-trust-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.20.12.0/28"
        region            = "us-west1"
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
      fw-spoke1-sub-region-1 = {
        name              = "fw-spoke1-sub"
        create_subnetwork = true
        ip_cidr_range     = "192.168.1.0/28"
        region            = "us-east1"
      },
      fw-spoke1-sub-region-2 = {
        name              = "fw-spoke1-sub"
        create_subnetwork = true
        ip_cidr_range     = "192.168.2.0/28"
        region            = "us-west1"
      }
    }
    firewall_rules = {
      allow-spoke1-ingress = {
        name             = "allow-spoke1-vpc"
        source_ranges    = ["192.168.0.0/16", "35.235.240.0/20", "10.10.12.0/28", "10.20.12.0/28"]
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
  }
}

# Static routes
routes = {
  fw-default-trust-region-1 = {
    name              = "fw-default-trust"
    destination_range = "0.0.0.0/0"
    vpc_network_key   = "fw-spoke1-vpc"
    lb_internal_key   = "internal-lb-region-1"
    region            = "us-east1"
    tags              = ["us-east1"]
  },
  fw-default-trust-region-2 = {
    name              = "fw-default-trust"
    destination_range = "0.0.0.0/0"
    vpc_network_key   = "fw-spoke1-vpc"
    lb_internal_key   = "internal-lb-region-2"
    region            = "us-west1"
    tags              = ["us-west1"]
  }
}

# VM-Series

vmseries_common = {
  ssh_keys            = "admin:<YOUR_SSH_KEY>"
  vmseries_image      = "vmseries-flex-byol-10210h9"
  machine_type        = "n2-standard-4"
  min_cpu_platform    = "Intel Cascade Lake"
  service_account_key = "sa-vmseries-01"
  bootstrap_options = {
    type                = "dhcp-client"
    mgmt-interface-swap = "enable"
  }
}

vmseries = {
  fw-vmseries-01 = {
    name   = "fw-vmseries-01"
    region = "us-east1"
    zone   = "us-east1-b"
    tags   = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
    bootstrap_options = {
      panorama-server = "1.1.1.1" # Modify this value as per deployment requirements
      dns-primary     = "8.8.8.8" # Modify this value as per deployment requirements
      dns-secondary   = "8.8.4.4" # Modify this value as per deployment requirements
    }
    bootstrap_template_map = {
      trust_gcp_router_ip   = "10.10.12.1"
      untrust_gcp_router_ip = "10.10.11.1"
      private_network_cidr  = "192.168.0.0/16"
      untrust_loopback_ip   = "1.1.1.1/32" # This is placeholder IP - you must replace it on the vmseries config with the LB public IP address (Region-1) after the infrastructure is deployed
      trust_loopback_ip     = "10.10.12.5/32"
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
        vpc_network_key  = "fw-untrust-vpc"
        subnetwork_key   = "fw-untrust-sub-region-1"
        private_ip       = "10.10.11.2"
        create_public_ip = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub-region-1"
        private_ip       = "10.10.10.2"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub-region-1"
        private_ip      = "10.10.12.2"
      }
    ]
  },
  fw-vmseries-02 = {
    name   = "fw-vmseries-02"
    region = "us-east1"
    zone   = "us-east1-c"
    tags   = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
    bootstrap_options = {
      panorama-server = "1.1.1.1" # Modify this value as per deployment requirements
      dns-primary     = "8.8.8.8" # Modify this value as per deployment requirements
      dns-secondary   = "8.8.4.4" # Modify this value as per deployment requirements
    }
    bootstrap_template_map = {
      trust_gcp_router_ip   = "10.10.12.1"
      untrust_gcp_router_ip = "10.10.11.1"
      private_network_cidr  = "192.168.0.0/16"
      untrust_loopback_ip   = "1.1.1.1/32" # This is placeholder IP - you must replace it on the vmseries config with the LB public IP address (Region-1) after the infrastructure is deployed
      trust_loopback_ip     = "10.10.12.5/32"
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
        vpc_network_key  = "fw-untrust-vpc"
        subnetwork_key   = "fw-untrust-sub-region-1"
        private_ip       = "10.10.11.3"
        create_public_ip = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub-region-1"
        private_ip       = "10.10.10.3"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub-region-1"
        private_ip      = "10.10.12.3"
      }
    ]
  },
  fw-vmseries-03 = {
    name   = "fw-vmseries-03"
    region = "us-west1"
    zone   = "us-west1-b"
    tags   = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
    bootstrap_options = {
      panorama-server = "1.1.1.1" # Modify this value as per deployment requirements
      dns-primary     = "8.8.8.8" # Modify this value as per deployment requirements
      dns-secondary   = "8.8.4.4" # Modify this value as per deployment requirements
    }
    bootstrap_template_map = {
      trust_gcp_router_ip   = "10.20.12.1"
      untrust_gcp_router_ip = "10.20.11.1"
      private_network_cidr  = "192.168.0.0/16"
      untrust_loopback_ip   = "2.2.2.2/32" # This is placeholder IP - you must replace it on the vmseries config with the LB public IP address (region_2) after the infrastructure is deployed
      trust_loopback_ip     = "10.20.12.5/32"
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
        vpc_network_key  = "fw-untrust-vpc"
        subnetwork_key   = "fw-untrust-sub-region-2"
        private_ip       = "10.20.11.2"
        create_public_ip = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub-region-2"
        private_ip       = "10.20.10.2"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub-region-2"
        private_ip      = "10.20.12.2"
      }
    ]
  },
  fw-vmseries-04 = {
    name   = "fw-vmseries-04"
    region = "us-west1"
    zone   = "us-west1-c"
    tags   = ["vmseries"]
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    bootstrap_bucket_key = "vmseries-bootstrap-bucket-01"
    bootstrap_options = {
      panorama-server = "1.1.1.1" # Modify this value as per deployment requirements
      dns-primary     = "8.8.8.8" # Modify this value as per deployment requirements
      dns-secondary   = "8.8.4.4" # Modify this value as per deployment requirements
    }
    bootstrap_template_map = {
      trust_gcp_router_ip   = "10.20.12.1"
      untrust_gcp_router_ip = "10.20.11.1"
      private_network_cidr  = "192.168.0.0/16"
      untrust_loopback_ip   = "2.2.2.2/32" # This is placeholder IP - you must replace it on the vmseries config with the LB public IP address (region_2) after the infrastructure is deployed
      trust_loopback_ip     = "10.20.12.5/32"
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
        vpc_network_key  = "fw-untrust-vpc"
        subnetwork_key   = "fw-untrust-sub-region-2"
        private_ip       = "10.20.11.3"
        create_public_ip = true
      },
      {
        vpc_network_key  = "fw-mgmt-vpc"
        subnetwork_key   = "fw-mgmt-sub-region-2"
        private_ip       = "10.20.10.3"
        create_public_ip = true
      },
      {
        vpc_network_key = "fw-trust-vpc"
        subnetwork_key  = "fw-trust-sub-region-2"
        private_ip      = "10.20.12.3"
      }
    ]
  }
}

# Spoke Linux VMs
linux_vms = {
  spoke1-vm = {
    linux_machine_type = "n2-standard-4"
    region             = "us-east1"
    zone               = "us-east1-b"
    linux_disk_size    = "50" # Modify this value as per deployment requirements
    vpc_network_key    = "fw-spoke1-vpc"
    subnetwork_key     = "fw-spoke1-sub-region-1"
    private_ip         = "192.168.1.2"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    service_account_key = "sa-linux-01"
    tags                = ["us-east1"]
  },
  spoke2-vm = {
    linux_machine_type = "n2-standard-4"
    region             = "us-west1"
    zone               = "us-west1-b"
    linux_disk_size    = "50" # Modify this value as per deployment requirements
    vpc_network_key    = "fw-spoke1-vpc"
    subnetwork_key     = "fw-spoke1-sub-region-2"
    private_ip         = "192.168.2.2"
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
    service_account_key = "sa-linux-01"
    tags                = ["us-west1"]
  }
}

# Internal Network Loadbalancer
lbs_internal = {
  internal-lb-region-1 = {
    name              = "internal-lb"
    region            = "us-east1"
    health_check_port = "80"
    backends          = ["fw-vmseries-01", "fw-vmseries-02"]
    ip_address        = "10.10.12.5"
    subnetwork_key    = "fw-trust-sub-region-1"
    vpc_network_key   = "fw-trust-vpc"
  },
  internal-lb-region-2 = {
    name              = "internal-lb"
    region            = "us-west1"
    health_check_port = "80"
    backends          = ["fw-vmseries-03", "fw-vmseries-04"]
    ip_address        = "10.20.12.5"
    subnetwork_key    = "fw-trust-sub-region-2"
    vpc_network_key   = "fw-trust-vpc"
  }
}

# External Network Loadbalancer
lbs_external = {
  external-lb-region-1 = {
    name     = "external-lb"
    region   = "us-east1"
    backends = ["fw-vmseries-01", "fw-vmseries-02"]
    rules = {
      all-ports-region-1 = {
        ip_protocol = "L3_DEFAULT"
      }
    }
    http_health_check_port         = "80"
    http_health_check_request_path = "/php/login.php"
  },
  external-lb-region-2 = {
    name     = "external-lb"
    region   = "us-west1"
    backends = ["fw-vmseries-03", "fw-vmseries-04"]
    rules = {
      all-ports-region-2 = {
        ip_protocol = "L3_DEFAULT"
      }
    }
    http_health_check_port         = "80"
    http_health_check_request_path = "/php/login.php"
  }
}