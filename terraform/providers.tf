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

provider "kubernetes" {
  config_path = "${path.root}/../kubeconfig.yaml"
}

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
