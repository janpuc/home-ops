terraform {
  required_version = ">= 1.7.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.0.0"
    }
    onepassword = {
      source = "1Password/onepassword"
      version = ">= 2.0.0"
    }
  }
}

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

module "flux" {
  source = "./modules/flux"

  cluster_region   = var.oci_region
  cluster_id       = module.oke.id
  cluster_endpoint = module.oke.endpoint
  cluster_ca_cert  = module.oke.certificate_authority_data

  github_organization = "janpuc"
  github_repository   = "home-ops"
  github_token        = data.onepassword_item.github_token.section[0].field[0].value
}

resource "local_file" "kubeconfig" {
  content  = yamlencode(module.oke.kubeconfig)
  filename = "${path.root}/../kubeconfig.yaml"
  file_permission = "0600"
}
