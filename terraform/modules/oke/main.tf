module "oke" {
  source  = "oracle-terraform-modules/oke/oci"
  version = "5.2.4"

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

  # Load Balancers
  allow_rules_public_lb = {
    # Temporary
    "Allow TCP ingress to public load balancers for Non-SSL traffic from anywhere" : {
      protocol = 6, port = 80, source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
    },
    "Allow TCP ingress to public load balancers for SSL traffic from anywhere" : {
      protocol = 6, port = 443, source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
    },
    # Satisfactory
    "Allow TCP ingress to public load balancers for Satisfactory API from anywhere" : {
      protocol = 6, port = 7777, source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
    },
    "Allow UDP ingress to public load balancers for Satisfactory Game from anywhere" : {
      protocol = 17, port = 7777, source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
    },
    "Allow TCP ingress to public load balancers for Satisfactory Messaging from anywhere" : {
      protocol = 6, port = 8888, source = "0.0.0.0/0", source_type = "CIDR_BLOCK",
    },
  }

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
      
      node_labels = {
        "oci.oraclecloud.com/custom-k8s-networking" = "true"
      }
    }
  }

  # Misc
  timezone      = "Europe/Warsaw"
  output_detail = true

  # # Cilium
  # cilium_install           = true
  # cilium_reapply           = false
  # cilium_namespace         = "kube-system"
  # cilium_helm_version      = "1.17.1"
  # cilium_helm_values       = {
  #   kubeProxyReplacement = true
  # }
}
