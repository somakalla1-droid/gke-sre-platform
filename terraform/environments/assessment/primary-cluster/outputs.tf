output "cluster_name" {
  description = "Primary GKE cluster name."
  value       = module.cluster.name
}

output "cluster_location" {
  description = "Primary GKE cluster location."
  value       = module.cluster.location
}

output "node_service_account_email" {
  description = "Service account used by primary GKE nodes."
  value       = module.cluster.node_service_account_email
}
