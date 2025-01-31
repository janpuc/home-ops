provider "onepassword" {
  account = "https://my.1password.com"
}

provider "oci" {
  region = var.oci_region
}

data "onepassword_item" "oci_credentials" {
  vault = "Kubernetes"
  title = "oci"
}

data "onepassword_item" "github_token" {
  vault = "Kubernetes"
  title = "github"
}

module "oke" {
  source = "./modules/oke"

  providers = {
    oci = oci
  }

  compartment_id = data.onepassword_item.oci_credentials.section[0].field[0].value

  oke_cluster_name    = "home-ops"
  oke_cluster_version = "v1.31.1"

  oke_node_pool_name = "home-ops-node-pool"
  oke_node_pool_size = 2

  oke_node_linux_version = "8"

  oke_pods_cidr     = "10.244.0.0/16"
  oke_services_cidr = "10.96.0.0/16"

  vcn_name      = "home-ops-vcn"
  vcn_dns_label = "homeops"
  vcn_cidr      = "10.0.0.0/16"
}

resource "local_file" "kubeconfig" {
  content  = yamlencode(module.oke.kubeconfig)
  filename = "${path.root}/../kubeconfig.yaml"
  file_permission = "0600"
}

data "github_repository" "this" {
  name = var.github_repository
}

resource "tls_private_key" "flux" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "this" {
  title      = "Flux"
  repository = data.github_repository.this.name
  key        = tls_private_key.flux.public_key_openssh
  read_only  = "false"
}

resource "flux_bootstrap_git" "this" {
  depends_on = [
    github_repository_deploy_key.this,
    module.oke
  ]

  embedded_manifests = true
  path               = "kubernetes/clusters/"
}
