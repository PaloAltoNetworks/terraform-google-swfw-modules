project     = "your-gcp-project-id"
region      = "us-central1"
name_prefix = "pan-nsi-"

# Set true to assign public IPs to the VM-Series mgmt NICs (lab only).
create_mgmt_public_ip = false

# Replace with your SSH public key.
ssh_keys = "ssh-ed25519 AAAA... admin@example.com"

# PAN-OS >= 11.2 is required for NSI GENEVE support.
vmseries_image = "vmseries-flex-byol-1120"

vmseries_common = {
  machine_type     = "n2-standard-8"
  min_cpu_platform = "Intel Cascade Lake"
  bootstrap_options = {
    type                        = "dhcp-client"
    dhcp-send-client-id         = "yes"
    dhcp-accept-server-hostname = "yes"
    dhcp-accept-server-domain   = "yes"
    dns-primary                 = "169.254.169.254"
    panorama-server             = "10.0.0.1"    # Replace with your Panorama IP
    tplname                     = "tpl-nsi-dev" # Panorama Template Stack name
    dgname                      = "dg-nsi-dev"  # Panorama Device Group name
    vm-auth-key                 = ""            # Generate with: request bootstrap vm-auth-key generate lifetime 8760
    # plugin-op-commands is automatically set to "geneve-inspect:enable" by the example
  }
}

# Two VM-Series instances, one per zone (active-active, no PAN-OS HA1/HA2).
vmseries = {
  fw-01 = { zone = "us-central1-a" }
  fw-02 = { zone = "us-central1-b" }
}

# Management VPC — NIC0 only. Kept in a separate VPC from data_vpc so that
# GCP's internal LB health checks target NIC1 (the GENEVE data interface).
mgmt_vpc = {
  name            = "pan-nsi-mgmt-vpc"
  subnetwork_name = "pan-nsi-mgmt-subnet"
  ip_cidr_range   = "10.0.0.0/24"
  firewall_rules = {
    allow-mgmt = {
      name             = "pan-nsi-allow-mgmt"
      source_ranges    = ["0.0.0.0/0"] # Replace with your operator CIDRs
      allowed_protocol = "tcp"
      allowed_ports    = ["22", "443", "3978"]
      priority         = 1000
    }
  }
}

# Data VPC — NIC1 / GENEVE ILB / NSI intercept deployment group.
# GCP health check ranges are allowed here so probes reach ethernet1/1.
data_vpc = {
  name            = "pan-nsi-data-vpc"
  subnetwork_name = "pan-nsi-data-subnet"
  ip_cidr_range   = "10.0.1.0/24"
  firewall_rules = {
    allow-healthchecks = {
      name = "pan-nsi-allow-hc"
      source_ranges = [
        "35.191.0.0/16",
        "130.211.0.0/22",
        "209.85.152.0/22",
        "209.85.204.0/22",
      ]
      allowed_protocol = "tcp"
      allowed_ports    = ["443"]
      priority         = 900
    }
  }
}


consumer_vpcs = {
  spoke-1 = {
    name            = "pan-nsi-spoke1-vpc"
    subnetwork_name = "pan-nsi-spoke1-subnet"
    ip_cidr_range   = "192.168.1.0/24"
    firewall_rules = {
      allow-internal = {
        name             = "pan-nsi-spoke1-allow-internal"
        source_ranges    = ["192.168.0.0/16"]
        allowed_protocol = "all"
        allowed_ports    = []
      }
      allow-iap-ssh = {
        name             = "pan-nsi-spoke1-allow-iap"
        source_ranges    = ["35.235.240.0/20"]
        allowed_protocol = "tcp"
        allowed_ports    = ["22"]
      }
    }
  }
  spoke-2 = {
    name            = "pan-nsi-spoke2-vpc"
    subnetwork_name = "pan-nsi-spoke2-subnet"
    ip_cidr_range   = "192.168.2.0/24"
    firewall_rules = {
      allow-internal = {
        name             = "pan-nsi-spoke2-allow-internal"
        source_ranges    = ["192.168.0.0/16"]
        allowed_protocol = "all"
        allowed_ports    = []
      }
      allow-iap-ssh = {
        name             = "pan-nsi-spoke2-allow-iap"
        source_ranges    = ["35.235.240.0/20"]
        allowed_protocol = "tcp"
        allowed_ports    = ["22"]
      }
    }
  }
}

# These are applied to each consumer VPC. The nsi_intercept module automatically
# sets action=apply_security_profile_group on all rules.
firewall_policy_rules = [
  {
    priority    = 1000
    direction   = "EGRESS"
    description = "Intercept all egress for PAN-OS inspection"
    match = {
      dest_ip_ranges = ["0.0.0.0/0"]
      layer4_configs = [{ ip_protocol = "all" }]
    }
  },
  {
    priority    = 1001
    direction   = "INGRESS"
    description = "Intercept all ingress for PAN-OS inspection"
    match = {
      src_ip_ranges  = ["0.0.0.0/0"]
      layer4_configs = [{ ip_protocol = "all" }]
    }
  },
]

# Set enable_ncc = false to skip NCC and manage consumer VPC connectivity separately.
enable_ncc   = true
ncc_topology = "MESH"

# Optional: Deploy small Debian VMs in each spoke for validating NSI interception.
linux_vms = {
  spoke1-vm = {
    zone                    = "us-central1-a"
    consumer_vpc_key        = "spoke-1"
    machine_type            = "e2-micro"
    disk_size_gb            = 20
    metadata_startup_script = <<-EOT
      #!/bin/bash
      apt-get update -y
      apt-get install -y nginx curl
      echo "spoke-1-vm" > /var/www/html/index.html
    EOT
  }
  spoke2-vm = {
    zone                    = "us-central1-b"
    consumer_vpc_key        = "spoke-2"
    machine_type            = "e2-micro"
    disk_size_gb            = 20
    metadata_startup_script = <<-EOT
      #!/bin/bash
      apt-get update -y
      apt-get install -y nginx curl
      echo "spoke-2-vm" > /var/www/html/index.html
    EOT
  }
}
