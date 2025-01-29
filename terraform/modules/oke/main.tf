terraform {
  required_version = ">= 1.0.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.0.0"
    }
  }
}

provider "oci" {
  region = var.region
}

resource "oci_core_vcn" "oke_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "oke-vcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-igw"
}

resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-nat-gw"
}

resource "oci_core_service_gateway" "svc_gw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
  display_name = "oke-svc-gw"
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "private-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gw.id
  }
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block        = "10.0.0.0/24"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.oke_vcn.id
  route_table_id    = oci_core_route_table.public_rt.id
  security_list_ids = [oci_core_security_list.public_security_list.id]
  display_name      = "public-subnet"
}

resource "oci_core_subnet" "private_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.oke_vcn.id
  route_table_id    = oci_core_route_table.private_rt.id
  security_list_ids = [oci_core_security_list.private_security_list.id]
  display_name      = "private-subnet"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_security_list" "public_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "public-security-list"

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "private_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "private-security-list"

  ingress_security_rules {
    protocol  = "all"
    source    = "10.0.0.0/16"
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/16"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/16"
    tcp_options {
      min = 12250
      max = 12250
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_containerengine_cluster" "oke_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "home-ops"
  vcn_id             = oci_core_vcn.oke_vcn.id

  endpoint_config {
    is_public_ip_enabled = false
    subnet_id            = oci_core_subnet.private_subnet.id
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.public_subnet.id]
  }
}

resource "oci_containerengine_node_pool" "oke_node_pool" {
  cluster_id         = oci_containerengine_cluster.oke_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "home-ops-node-pool"
  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.private_subnet.id
    }
    size = 2
  }
  node_shape = "VM.Standard.A1.Flex"
  node_shape_config {
    memory_in_gbs = 12
    ocpus         = 2
  }
  node_source_details {
    image_id    = data.oci_core_images.oke_images.images[0].id
    source_type = "IMAGE"
    boot_volume_size_in_gbs = 100
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oke_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

data "oci_containerengine_cluster_kube_config" "oke_kubeconfig" {
  cluster_id = oci_containerengine_cluster.oke_cluster.id
}
