terraform {
  required_version = "~>1.8"
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "~>1.0"
    }
    github = {
      source  = "integrations/github"
      version = "~>6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~>2.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~>0.80"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0-alpha.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

provider "flux" {
  kubernetes = {
    host = module.kubernetes.host

    client_certificate     = base64decode(module.kubernetes.client_certificate)
    client_key             = base64decode(module.kubernetes.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
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
  token = local.github_token
}

provider "kubernetes" {
  host = module.kubernetes.host

  client_certificate     = base64decode(module.kubernetes.client_certificate)
  client_key             = base64decode(module.kubernetes.client_key)
  cluster_ca_certificate = base64decode(module.kubernetes.cluster_ca_certificate)
}

provider "onepassword" {
  account = "https://my.1password.com"
}

provider "proxmox" {
  endpoint = local.proxmox_endpoint

  username = local.proxmox_username
  password = local.proxmox_password

  insecure = true
}
