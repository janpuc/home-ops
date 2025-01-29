provider "flux" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_cert)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["ce", "cluster", "generate-token", "--cluster-id", var.cluster_id, "--region", var.cluster_region]
      command     = "/opt/homebrew/bin/oci" # TODO: Change to `oci` once I fix path var issues
    }
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
  token = var.github_token
}