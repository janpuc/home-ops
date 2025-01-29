terraform {
  required_version = ">= 1.0.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.0.0"
    }
    onepassword = {
      source = "1Password/onepassword"
      version = "2.1.2"
    }
  }
}

provider "onepassword" {
  account = "https://my.1password.com"
}

provider "oci" {
  region = "eu-frankfurt-1"
}

data "onepassword_item" "oci_credentials" {
  vault = "Kubernetes"
  title = "oci"
}

module "oke_cluster" {
  source = "./modules/oke"

  compartment_ocid     = data.onepassword_item.oci_credentials.section[0].field[0].value
  region               = "eu-frankfurt-1"
  kubernetes_version   = "v1.31.1"
}

resource "local_file" "kubeconfig" {
  content  = module.oke_cluster.kubeconfig
  filename = "${path.root}/../kubeconfig.yaml"
}

output "available_kubernetes_upgrades" {
  value = module.oke_cluster.available_kubernetes_upgrades
}
