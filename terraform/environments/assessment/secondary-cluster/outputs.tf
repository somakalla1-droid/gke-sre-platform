output "cluster_name" {
  description = "Secondary GKE cluster name."
  value       = module.cluster.name
}

output "cluster_location" {
  description = "Secondary GKE cluster location."
  value       = module.cluster.location
}

output "node_service_account_email" {
  description = "Service account used by secondary GKE nodes."
  value       = module.cluster.node_service_account_email
}
