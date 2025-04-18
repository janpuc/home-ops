terraform {
  required_version = ">= 1.7.0"
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.4"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.1"
    }
    helm = {
      source = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.36.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = ">= 4.0"
    }
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
