terraform {
  required_version = ">= 1.7.0"
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.2"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.1"
    }
    tls = {
        source = "hashicorp/tls"
        version = ">= 4.0"
    }
  }
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
  depends_on = [github_repository_deploy_key.this]

  embedded_manifests = true
  path               = "kubernetes"
}
