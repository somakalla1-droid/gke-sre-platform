output "network_name" { value = google_compute_network.main.name }
output "primary_subnet_name" { value = google_compute_subnetwork.primary.name }
output "secondary_subnet_name" { value = google_compute_subnetwork.secondary.name }
output "artifact_registry_repository" { value = google_artifact_registry_repository.apps.repository_id }
output "cloud_armor_policy_name" { value = google_compute_security_policy.assessment_web_waf.name }
output "response_demo_secret_id" { value = google_secret_manager_secret.response_demo_token.secret_id }
output "response_demo_secret_name" { value = google_secret_manager_secret.response_demo_token.name }
output "application_logs_dataset_id" { value = google_bigquery_dataset.assessment_app_logs.dataset_id }
output "application_request_log_sink_name" { value = google_logging_project_sink.assessment_app_requests.name }
output "grafana_observability_service_account_email" {
  value = google_service_account.grafana_observability.email
}
