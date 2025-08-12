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
  source = "./modules/hetzner-talos"
  # version = "~>2.1"

  # cluster_name = "aether"
  hcloud_token = local.hetzner_token
}
