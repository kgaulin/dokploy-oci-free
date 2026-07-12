# VCN configuration
resource "oci_core_vcn" "dokploy_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_id
  display_name   = "network-dokploy-${random_string.resource_code.result}"
  dns_label      = "vcn${random_string.resource_code.result}"
}

# Subnet configuration
resource "oci_core_subnet" "dokploy_subnet" {
  cidr_block     = "10.0.0.0/24"
  compartment_id = var.compartment_id
  display_name   = "subnet-dokploy-${random_string.resource_code.result}"
  dns_label      = "subnet${random_string.resource_code.result}"
  route_table_id = oci_core_vcn.dokploy_vcn.default_route_table_id
  vcn_id         = oci_core_vcn.dokploy_vcn.id

  # Attach the security list
  security_list_ids = [oci_core_security_list.dokploy_security_list.id]
}

# Internet Gateway configuration
resource "oci_core_internet_gateway" "dokploy_internet_gateway" {
  compartment_id = var.compartment_id
  display_name   = "Internet Gateway network-dokploy"
  enabled        = true
  vcn_id         = oci_core_vcn.dokploy_vcn.id
}

# Default Route Table
resource "oci_core_default_route_table" "dokploy_default_route_table" {
  manage_default_resource_id = oci_core_vcn.dokploy_vcn.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.dokploy_internet_gateway.id
  }
}

# Security List for Dokploy
resource "oci_core_security_list" "dokploy_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.dokploy_vcn.id
  display_name   = "Dokploy Security List"

  # Ingress Rules for Dokploy
  ingress_security_rules {
    protocol = "6" # TCP
    source   = var.dashboard_allowed_cidr
    tcp_options {
      min = 3000
      max = 3000
    }
    description = "Allow HTTP traffic for Dokploy dashboard on port 3000"
  }

  # SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
    description = "Allow SSH traffic on port 22"
  }

  # HTTP & HTTPS traffic
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
    description = "Allow HTTP traffic on port 80"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
    description = "Allow HTTPS traffic on port 443"
  }

  # ICMP traffic
  ingress_security_rules {
    description = "ICMP traffic for 3, 4"
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  ingress_security_rules {
    description = "ICMP traffic for 3"
    icmp_options {
      code = "-1"
      type = "3"
    }
    protocol    = "1"
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    stateless   = "false"
  }

  # Traefik Proxy
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 81
      max = 81
    }
    description = "Allow Traefik HTTP traffic on port 81"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 444
      max = 444
    }
    description = "Allow Traefik HTTPS traffic on port 444"
  }

  # Ingress rules for Docker Swarm — restricted to the VCN network only.
  # These ports MUST NOT be exposed to the public internet (see Dokploy security docs).
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 2376
      max = 2376
    }
    description = "Docker daemon (port 2376) - cluster network only"
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 2377
      max = 2377
    }
    description = "Swarm management (port 2377) - cluster network only"
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 7946
      max = 7946
    }
    description = "Swarm node discovery TCP (port 7946) - cluster network only"
  }

  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    udp_options {
      min = 7946
      max = 7946
    }
    description = "Swarm node discovery UDP (port 7946) - cluster network only"
  }

  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    udp_options {
      min = 4789
      max = 4789
    }
    description = "Swarm overlay VXLAN (port 4789, no auth) - cluster network only"
  }

  # Egress Rule (optional, if needed)
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all egress traffic"
  }
}
