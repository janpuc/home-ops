output "kubeconfig" {
  description = "Kubeconfig"
  value       = module.oke.cluster_kubeconfig
}

output "endpoint" {
  description = "OKE Cluster Endpoint"
  value       = module.oke.cluster_endpoints.public_endpoint
}

output "certificate_authority_data" {
  description = "OKE Cluster CA"
  value       = module.oke.cluster_ca_cert
}

output "id" {
  description = "OKE Cluster ID"
  value       = module.oke.cluster_id
}

output "lb_nsg_id" {
  description = "OKE Public Load Balancer NSG ID"
  value = module.oke.pub_lb_nsg_id
}