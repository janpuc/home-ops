data "onepassword_item" "bootstrap_secrets" {
  vault = "Kubernetes"
  title = "bootstrap-aether"
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

  op_credentials = try(local.fields_by_section["1Password"]["1password-credentials.json"].value, null)
  op_token       = try(local.fields_by_section["1Password"]["token"].value, null)

  github_token = try(local.fields_by_section["Github"]["token"].value, null)

  proxmox_username = try(local.fields_by_section["Proxmox"]["username"].value, null)
  proxmox_password = try(local.fields_by_section["Proxmox"]["password"].value, null)
  proxmox_endpoint = try(local.fields_by_section["Proxmox"]["endpoint"].value, null)

  proxmox_ccm_token_id     = try(local.fields_by_section["Proxmox"]["ccm_token_id"].value, null)
  proxmox_ccm_token_secret = try(local.fields_by_section["Proxmox"]["ccm_token_secret"].value, null)

  proxmox_csi_token_id     = try(local.fields_by_section["Proxmox"]["csi_token_id"].value, null)
  proxmox_csi_token_secret = try(local.fields_by_section["Proxmox"]["csi_token_secret"].value, null)

  cilium_ca_crt = try(local.fields_by_section["Cilium"]["ca_crt"].value, null)
  cilium_ca_key = try(local.fields_by_section["Cilium"]["ca_key"].value, null)
}

module "kubernetes" {
  source = "github.com/janpuc/terraform-proxmox-talos?ref=mcsapi&depth=1"

  proxmox = {
    cluster_name  = var.cluster_name
    node_name     = "aether"
    iso_datastore = "local"
    datastore     = "local"
  }

  cluster = {
    id                               = 2
    name                             = var.cluster_name
    talos_version                    = "1.11.0"
    talos_ccm_version                = "0.5.0"
    kubernetes_version               = "1.34.0"
    gateway_api_crds_version         = "1.3.0"
    prometheus_operator_crds_version = "0.85.0"
    cilium_ca_crt                    = local.cilium_ca_crt
    cilium_ca_key                    = local.cilium_ca_key

    multi_cluster_configuration = {
      mesh_api_lb    = "10.69.21.11"
      mcsapi_enabled = true
      clusters = {
        gaia = {
          k8s_cidr    = "10.208.0.0/15"
          gateway_ip  = "10.69.11.1"
          mesh_api_lb = "10.69.11.11"
        }
      }
    }
  }

  network = {
    gateway  = "10.69.21.1"
    kube_vip = "10.69.21.10"

    subnets = {
      vm      = "10.69.21.0/24"
      pod     = "10.210.0.0/16"
      service = "10.211.0.0/16"
      k8s     = "10.210.0.0/15"
    }

    bridge = "vnet0"
  }

  control_plane = {
    count      = 3
    base_vm_id = 1000
    cpu = {
      cores = 2
      numa  = true
      type  = "host"
    }
    memory = {
      dedicated = 4096
    }
    disk = {
      size = 20
    }
  }

  node_groups = {
    "worker" = {
      count      = 4
      base_vm_id = 1100
      cpu = {
        cores = 3
        numa  = true
      }
      memory = {
        dedicated = 65536
      }
      disk = {
        size = 20
      }
    }
  }
}

resource "local_file" "talosconfig" {
  filename = "talosconfig"
  content  = yamlencode(module.kubernetes.talosconfig)
}

resource "local_file" "kubeconfig" {
  filename = "kubeconfig"
  content  = yamlencode(module.kubernetes.kubeconfig)
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  lifecycle {
    ignore_changes = [
      metadata["annotations"],
      metadata["labels"]
    ]
  }

  depends_on = [module.kubernetes]
}

resource "kubernetes_secret" "op_credentials" {
  metadata {
    name      = "op-credentials"
    namespace = "external-secrets"
  }

  data = {
    "1password-credentials.json" = base64encode(local.op_credentials)
  }

  type = "opaque"

  immutable = true

  depends_on = [kubernetes_namespace.external_secrets]
}

resource "kubernetes_secret" "op_token" {
  metadata {
    name      = "op-token"
    namespace = "external-secrets"
  }

  data = {
    "token" = local.op_token
  }

  type = "opaque"

  immutable = true

  depends_on = [kubernetes_namespace.external_secrets]
}

data "onepassword_vault" "kubernetes_vault" {
  name = "Kubernetes"
}

resource "kubernetes_secret" "proxmox_ccm" {
  metadata {
    name      = "proxmox-ccm"
    namespace = "kube-system"
  }

  data = {
    "config.yaml" = yamlencode({
      clusters = [{
        url          = "${local.proxmox_endpoint}/api2/json"
        insecure     = true
        token_id     = local.proxmox_ccm_token_id
        token_secret = local.proxmox_ccm_token_secret
        region       = "gaia"
      }]
    })
  }

  type = "opaque"

  depends_on = [module.kubernetes]
}

resource "kubernetes_secret" "proxmox_csi" {
  metadata {
    name      = "proxmox-csi"
    namespace = "kube-system"
  }

  data = {
    "config.yaml" = yamlencode({
      clusters = [{
        url          = "${local.proxmox_endpoint}/api2/json"
        insecure     = true
        token_id     = local.proxmox_csi_token_id
        token_secret = local.proxmox_csi_token_secret
        region       = var.cluster_name
      }]
    })
  }

  type = "opaque"

  depends_on = [module.kubernetes]
}
