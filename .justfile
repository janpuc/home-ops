export AWS_ENDPOINT_URL_S3 := "op://Kubernetes/terraform/s3_endpoint"
export AWS_ACCESS_KEY_ID := "op://Kubernetes/terraform/s3_access_key"
export AWS_SECRET_ACCESS_KEY := "op://Kubernetes/terraform/s3_secret_key"

gaia *CMD:
  op run -- tofu -chdir=terraform/gaia {{CMD}}

aether *CMD:
  op run -- tofu -chdir=terraform/aether {{CMD}}
