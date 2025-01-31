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

provider "github" {
  owner = var.github_organization
  token = data.onepassword_item.github_token.section[0].field[0].value
}
