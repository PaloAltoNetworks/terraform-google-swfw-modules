# Palo Alto Networks VM-series firewall deployment

To manage via ssh/https please connect to the second interface (the `nic1`) of a VM-series firewall. The primary interface is by default not used for management.

When troubleshooting you can use this module also with a good ol' Linux image. Instead of booting PAN-OS, you can just re-create the same instance with Linux. It boots faster, it's probably more familiar, but there is a caveat when connecting from outside the GCP VPC Network:

- One cannot connect to `nic1` of Linux, because GCP DHCP doesn't ever furnish it with a default route. Connect to the primary interface (the `nic0`) for both data traffic and management traffic.
