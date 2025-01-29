terraform {
  backend "s3" {
    bucket   = "home-ops-state"
    region   = "eu-frankfurt-1"
    key      = "home-ops/terraform.tfstate"
    profile  = "oci"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true

    endpoints = {
      s3 = "https://fr2kdr2nkebq.compat.objectstorage.eu-frankfurt-1.oraclecloud.com"
    }
  }
}
