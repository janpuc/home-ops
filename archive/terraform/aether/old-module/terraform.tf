terraform {
  required_version = "~>1.12"
  required_providers {
    onepassword = {
      source = "1Password/onepassword"
      version = "~>2.0"
    }
  }
}
