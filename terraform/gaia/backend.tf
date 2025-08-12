terraform {
  backend "s3" {
    bucket = "home-ops-tfstate"
    region = "main"
    key    = "gaia/terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
