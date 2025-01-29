variable "compartment_ocid" {
  description = "Compartment OCID where resources will be created"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE cluster"
  type        = string
  default     = "v1.31.1"
}
