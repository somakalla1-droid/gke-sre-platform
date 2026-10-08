output "name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "location" {
  description = "GKE cluster location."
  value       = google_container_cluster.this.location
}

output "node_service_account_email" {
  description = "Service account used by the GKE nodes."
  value       = google_service_account.nodes.email
}
