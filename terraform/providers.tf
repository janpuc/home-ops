provider "flux" {
  kubernetes = {
    config_path = "${path.root}/../kubeconfig.yaml"
  }
  git = {
    url = "ssh://git@github.com/${var.github_organization}/${var.github_repository}.git"
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "${path.root}/../kubeconfig.yaml"
  }
}

provider "kubernetes" {
  config_path = "${path.root}/../kubeconfig.yaml"
}

# provider "kubernetes" {
#   host                   = module.oke.endpoint
#   cluster_ca_certificate = base64decode(module.oke.certificate_authority_data)
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     args        = ["ce", "cluster", "generate-token", "--cluster-id", module.oke.id, "--region", var.oci_region]
#     command     = "/opt/homebrew/bin/oci" # TODO: Change to `oci` once I fix path var issues
#   }
# }

provider "github" {
  owner = var.github_organization
  token = local.github_token
}

provider "onepassword" {
  account = "https://my.1password.com"
}

provider "oci" {
  region = var.oci_region
}
