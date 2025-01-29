output "cluster_id" {
  description = "OKE Cluster ID"
  value       = oci_containerengine_cluster.oke_cluster.id
}

output "kubeconfig" {
  description = "Kubeconfig file content"
  value       = data.oci_containerengine_cluster_kube_config.oke_kubeconfig.content
  sensitive   = true
}

output "vcn_id" {
  description = "Created VCN ID"
  value       = oci_core_vcn.oke_vcn.id
}

output "available_kubernetes_upgrades" {
  description = "Available kubernetes upgrades"
  value       = oci_containerengine_cluster.oke_cluster.available_kubernetes_upgrades
}
