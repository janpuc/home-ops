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

  github_token   = try(local.fields_by_section["Github"]["token"].value, null)
  hetzner_token  = try(local.fields_by_section["Hetzner"]["token"].value, null)
  op_credentials = try(local.fields_by_section["1Password"]["1password-credentials.json"].value, null)
  op_token       = try(local.fields_by_section["1Password"]["token"].value, null)
}

module "kubernetes" {
  source = "hcloud-k8s/kubernetes/hcloud"
  version = "~> 3.0"

  cluster_name = "aether"
  hcloud_token = local.hetzner_token

  cluster_kubeconfig_path = "kubeconfig"
  cluster_talosconfig_path = "talosconfig"

  control_plane_nodepools = [
    { name = "control", type = "cax11", location = "fsn1", count = 1 }
  ]

  worker_nodepools = [
    { name = "worker", type = "cax11", location = "fsn1", count = 2 }
  ]

  kube_api_load_balancer_enabled = false # Costs 6 euro

  # Cilium
  cilium_hubble_enabled          = true
  cilium_hubble_relay_enabled    = true
  cilium_hubble_ui_enabled       = true
  cilium_service_monitor_enabled = true

  # Talos
  talos_public_ipv4_enabled = true
  talos_public_ipv6_enabled = true # Needed

  cluster_delete_protection = false # Change before `terraform destroy`
}
