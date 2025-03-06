module "oke" {
  source  = "oracle-terraform-modules/oke/oci"
  version = "5.2.4-beta.1"

  providers = {
    oci.home = oci
  }

  compartment_id = var.compartment_id

  # Network
  assign_dns = true
  create_vcn = true

  vcn_cidrs     = [var.vcn_cidr]
  vcn_dns_label = var.vcn_dns_label
  vcn_name      = var.vcn_name

  # Cluster
  cluster_name = var.oke_cluster_name
  cluster_type = "basic"

  kubernetes_version = var.oke_cluster_version

  cni_type = "flannel"

  control_plane_is_public           = true
  assign_public_ip_to_control_plane = true

  control_plane_allowed_cidrs = ["0.0.0.0/0"]

  pods_cidr     = var.oke_pods_cidr
  services_cidr = var.oke_services_cidr

  # Bastion
  create_bastion = false

  # Operator
  create_operator = false

  # Workers
  worker_pool_mode = "node-pool"
  worker_pool_size = var.oke_node_pool_size

  worker_pools = {
    oke-vm-standard = {
      description      = "OKE-managed Node Pool with OKE Oracle Linux",
      shape            = "VM.Standard.A1.Flex",
      create           = true,
      ocpus            = 2,
      memory           = 12,
      boot_volume_size = 100,
      os               = "Oracle Linux",
      os_version       = var.oke_node_linux_version,
    }
  }

  # Misc
  timezone      = "Europe/Warsaw"
  output_detail = true
}
