variable "cluster_region" {
  description = "OKE cluster region"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "cluster_id" {
  description = "OKE cluster ID"
  type        = string
}

variable "cluster_endpoint" {
  description = "OKE cluster endpoint"
  type        = string
}

variable "cluster_ca_cert" {
  description = "OKE cluster CA certificate"
  type        = string
}

variable "github_organization" {
  description = "Github organization"
  type        = string
}

variable "github_token" {
  description = "Github organization"
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "Github repository"
  type        = string
}
