data "onepassword_item" "bootstrap_secrets" {
  vault = "Kubernetes"
  title = "bootstrap"
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

  oracle_compartment_id = try(local.fields_by_section["Oracle"]["compartment_id"].value, null)
  github_token          = try(local.fields_by_section["Github"]["token"].value, null)
  op_credentials        = try(local.fields_by_section["1Password"]["1password-credentials.json"].value, null)
  op_token              = try(local.fields_by_section["1Password"]["token"].value, null)

  gateway_api_yamls = provider::kubernetes::manifest_decode_multi(data.http.gateway_api_crds.response_body)

  processed_gateway_api_yamls = [
    for manifest in local.gateway_api_yamls : {
      for k, v in manifest : k => v if k != "status"
    }
  ]
}

module "oke" {
  source = "./modules/oke"

  providers = {
    oci = oci
  }

  compartment_id = local.oracle_compartment_id

  oke_cluster_name    = "aether"
  oke_cluster_version = "v1.31.1"

  oke_node_pool_name = "aether-node-pool"
  oke_node_pool_size = 2

  oke_node_linux_version = "8"

  oke_pods_cidr     = "10.244.0.0/16"
  oke_services_cidr = "10.96.0.0/16"

  vcn_name      = "aether-vcn"
  vcn_dns_label = "aether"
  vcn_cidr      = "10.0.0.0/16"
}

resource "local_file" "kubeconfig" {
  content  = yamlencode(module.oke.kubeconfig)
  filename = "${path.root}/../kubeconfig.yaml"
  file_permission = "0600"
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
  depends_on = [
    github_repository_deploy_key.this,
    module.oke,
    local_file.kubeconfig,
    kubernetes_namespace.external_secrets
  ]

  embedded_manifests = true
  path               = "kubernetes/clusters/aether"
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

  depends_on = [
    module.oke,
    local_file.kubeconfig
  ]
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

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
}

resource "kubernetes_manifest" "install_gateway_api_crds" {
  for_each = {
    for manifest in local.processed_gateway_api_yamls :
    "${manifest.kind}--${manifest.metadata.name}" => manifest
  }
  manifest = each.value

  computed_fields = [
    "metadata.labels",
    "metadata.annotations",
    "metadata.creationTimestamp"
  ]
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.17.1"
  namespace  = "kube-system"

  cleanup_on_fail   = false
  force_update      = true
  dependency_update = true
  lint              = true
  atomic            = false
  timeout           = 800

  values = [
    yamlencode({
      annotateK8sNode = true
      cluster = {
        id   = 1
        name = "aether"
      }
      clustermesh = {
        apiserver = {
          kvstoremesh = {
            enabled = false
          }
        }
        useAPIServer = false
      }
      cni = {
        exclusive = true
        install   = true
      }
      hubble = {
        metrics = {
          dashboards = {
            enabled = false
          }
        }
        relay = {
          enabled = true
        }
        ui = {
          enabled = true
        }
      }
      installNoConntrackIptablesRules = false
      ipam = {
        mode = "kubernetes"
      }
      k8s = {
        requireIPv4PodCIDR = true
      }
      # k8sServiceHost = module.oke.endpoint
      k8sServicePort = 6443
      kubeProxyReplacement = false
      operator = {
        prometheus = {
          enabled = false
        }
      }
      pmtuDiscovery = {
        enabled = true
      }
      rollOutCiliumPods = true
      tunnelProtocol = "vxlan"
    })
  ]

  # lifecycle {
  #   ignore_changes = [metadata]
  # }

  depends_on = [
    kubernetes_manifest.install_gateway_api_crds
  ]
}