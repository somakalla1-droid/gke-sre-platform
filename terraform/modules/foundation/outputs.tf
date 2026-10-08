output "network_name" { value = google_compute_network.main.name }
output "primary_subnet_name" { value = google_compute_subnetwork.primary.name }
output "secondary_subnet_name" { value = google_compute_subnetwork.secondary.name }
output "artifact_registry_repository" { value = google_artifact_registry_repository.apps.repository_id }
output "response_demo_secret_id" { value = google_secret_manager_secret.response_demo_token.secret_id }
output "response_demo_secret_name" { value = google_secret_manager_secret.response_demo_token.name }
