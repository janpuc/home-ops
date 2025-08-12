data "onepassword_item" "bootstrap_secrets" {
  vault = "Kubernetes"
  title = "bootstrap-gaia"
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
}

module "kubernetes" {
  source = "github.com/janpuc/terraform-proxmox-talos?ref=v0.0.1-alpha.3&depth=1"

  proxmox = {
    node_name     = "proxmox"
    iso_datastore = "local"
    datastore     = "local-lvm"
  }

  cluster = {
    name               = var.cluster_name
    talos_version      = "1.10.6"
    kubernetes_version = "1.33.3"
  }

  network = {
    gateway  = "10.69.11.1"
    kube_vip = "10.69.11.10"

    vlan_id = 11

    subnets = {
      vm      = "10.69.11.0/24"
      pod     = "10.208.0.0/16"
      service = "10.209.0.0/16"
    }
    dns = {
      servers = ["192.168.69.1", "1.1.1.1"]
      domain  = "localdomain"
    }
  }

  control_plane = {
    count      = 1
    base_vm_id = 1100
    cpu = {
      cores = 2
      numa  = true
      type  = "host"
    }
    memory = {
      dedicated = 2048
    }
    disk = {
      size = 15
    }
    image = {
      file_id = "local:iso/talos-amd64-v1.10.6.iso"
    }
  }

  node_groups = {
    "worker" = {
      count = 3
      base_vm_id = 1200
      cpu = {
        cores = 2
      }
      memory = {
        dedicated = 2048
        floating  = 3072
      }
      disk = {
        size = 15
      }
      image = {
        file_id = "local:iso/talos-amd64-v1.10.6.iso"
      }
    }
    # "worker-gpu" = {
    #   count       = 1
    #   base_vm_id = 1300
    #   cpu = {
    #     cores        = 4
    #     numa         = true
    #     affinity     = "0-3,6-9"
    #   }
    #   memory = {
    #     dedicated = 4096
    #   }
    #   disk = {
    #     size = 15
    #   }
    #   image = {
    #     extensions     = ["nonfree-kmod-nvidia-lts", "nvidia-container-toolkit-lts"]
    #     kernel_modules = ["nvidia", "nvidia_uvm", "nvidia_drm", "nvidia_modeset"]
    #     sysctls = {
    #       "net.core.bpf_jit_harden" = "1"
    #     }
    #   }
    #   overrides = {
    #     1301 = {
    #       hostpci = {
    #         id = "0000:01:00.0"
    #       }
    #     }
    #   }
    # }
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
