# General
project     = "<YOUR_PROJECT_ID>"
org_id      = "<YOUR_ORG_ID>"
region      = "us-central1" # Modify this value as per deployment requirements
name_prefix = ""

service_accounts = {
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
  fw-hosts-vpc = {
    vpc_name                        = "fw-hosts-vpc"
    create_network                  = true
    delete_default_routes_on_create = false
    mtu                             = "1460"
    routing_mode                    = "REGIONAL"
    subnetworks = {
      fw-hosts-sub = {
        name              = "fw-hosts-sub"
        create_subnetwork = true
        ip_cidr_range     = "10.0.0.0/24"
        region            = "us-central1"
      }
    }
  },
}

cloud_nats = {
  fw-hosts-nat = {
    name                           = "fw-hosts-nat"
    region                         = "us-central1"
    router_name                    = "fw-hosts-usc1-nat-router"
    vpc_network_key                = "fw-hosts-vpc"
    min_ports_per_vm               = 1024
    max_ports_per_vm               = 4096
    enable_dynamic_port_allocation = true
    log_config_enable              = true
    subnetworks = [
      {
        subnetwork_key = "fw-hosts-sub"
      }
    ]
  }
}

linux_vms = {
  client-vm = {
    linux_machine_type = "f1-micro"
    zone               = "us-central1-a"
    linux_disk_size    = "50" # Modify this value as per deployment requirements
    vpc_network_key    = "fw-hosts-vpc"
    subnetwork_key     = "fw-hosts-sub"
    private_ip         = "10.0.0.10"
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    service_account_key     = "sa-linux-01"
    metadata_startup_script = <<SCRIPT
    #! /bin/bash 
    apt-get update 
    apt-get install apache2-utils mtr iperf3 tcpdump -y
    SCRIPT
  },
  web-server-vm = {
    linux_machine_type  = "f1-micro"
    zone                = "us-central1-a"
    linux_disk_size     = "50" # Modify this value as per deployment requirements
    vpc_network_key     = "fw-hosts-vpc"
    subnetwork_key      = "fw-hosts-sub"
    private_ip          = "10.0.0.20"
    service_account_key = "sa-linux-01"
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    metadata_startup_script = <<SCRIPT
    #! /bin/bash 
    sudo apt-get update
    sudo apt-get install coreutils -y
    sudo apt-get install php -y
    sudo apt-get install apache2 tcpdump iperf3 -y 
    sudo a2ensite default-ssl 
    sudo a2enmod ssl 
    # Apache configuration:
    sudo rm -f /var/www/html/index.html
    sudo wget -O /var/www/html/index.php https://raw.githubusercontent.com/wwce/terraform/master/azure/transit_2fw_2spoke_common/scripts/showheaders.php 
    systemctl restart apache2
    SCRIPT
  },
}

firewall_endpoints = {
  endpoint_a = {
    firewall_endpoint_name             = "endpoint-a"
    zone                               = "us-central1-a"
    firewall_endpoint_association_name = "fwe-assoc-new-a"
    vpc_network_key                    = "fw-hosts-vpc"
  }
}

network_security_profiles = {
  profile-a = {
    profile_name              = "profile-a"
    profile_group_name        = "group-profile-a"
    profile_description       = "Test Security Profile"
    profile_group_description = "Test Group Security Profile"
    severity_overrides = {
      "LOW"           = "DENY"
      "INFORMATIONAL" = "ALERT"
      "MEDIUM"        = "DENY"
      "HIGH"          = "DENY"
      "CRITICAL"      = "DENY"
    }
  }
}

network_policies = {
  policy_name = "main-network-policy"
  description = "This is a network policy for the ngfw project"
  network_associations = {
    assoc-1 = {
      policy_association_name = "network-policy-a-assoc"
      vpc_network_key         = "fw-hosts-vpc"
    }
  }
  rules = {
    allow_some_ingress = {
      rule_name          = "allow_some_ingress"
      description        = "Allow some ingress traffic"
      direction          = "INGRESS"
      enable_logging     = true
      tls_inspect        = false
      priority           = 100
      action             = "apply_security_profile_group"
      security_group_key = "profile-a"
      dest_ip_ranges     = ["10.0.0.0/24"]
      src_ip_ranges      = ["0.0.0.0/0"]
      ip_protocol        = "all"
    }
    allow_some_egress = {
      rule_name          = "allow_some_egress"
      description        = "Allow some egress traffic"
      direction          = "EGRESS"
      enable_logging     = true
      tls_inspect        = false
      priority           = 101
      action             = "apply_security_profile_group"
      security_group_key = "profile-a"
      dest_ip_ranges     = ["0.0.0.0/0"]
      src_ip_ranges      = ["10.0.0.0/24"]
      ip_protocol        = "all"
    }
  }
}
