output "fleet_id" {
  description = "Default fleet resource managed for the assessment."
  value       = google_gke_hub_fleet.assessment.id
}

output "primary_membership" {
  description = "Primary cluster fleet membership used as the config cluster."
  value       = google_gke_hub_membership.primary.id
}

output "secondary_membership" {
  description = "Secondary cluster fleet membership."
  value       = google_gke_hub_membership.secondary.id
}

output "multi_cluster_services_feature" {
  description = "Fleet Multi-cluster Services feature resource."
  value       = google_gke_hub_feature.multi_cluster_services.id
}

output "multi_cluster_gateway_feature" {
  description = "Fleet multi-cluster Gateway controller feature resource."
  value       = google_gke_hub_feature.multi_cluster_gateway.id
}
