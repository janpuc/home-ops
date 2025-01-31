data "onepassword_item" "bootstrap_secrets" {
  vault = "Kubernetes"
  title = "bootstrap"
}

locals {
  sections_by_label = { 
    for section in data.onepassword_item.bootstrap_secrets.section : 
    section.label => section 
  }

  fields_by_section = {
    for section in data.onepassword_item.bootstrap_secrets.section :
    section.label => {
      for field in try(section.field, []) :
      field.label => field
    }
  }

  oracle_compartment_id = try(local.fields_by_section["Oracle"]["compartment_id"].value, null)
  github_token          = try(local.fields_by_section["Github"]["token"].value, null)
}

module "oke" {
  source = "./modules/oke"

  providers = {
    oci = oci
  }

  compartment_id = local.oracle_compartment_id

  oke_cluster_name    = "aether"
  oke_cluster_version = "v1.31.1"

  oke_node_pool_name = "aether-node-pool"
  oke_node_pool_size = 2

  oke_node_linux_version = "8"

  oke_pods_cidr     = "10.244.0.0/16"
  oke_services_cidr = "10.96.0.0/16"

  vcn_name      = "aether-vcn"
  vcn_dns_label = "aether"
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
  path               = "kubernetes/clusters/aether"
}
