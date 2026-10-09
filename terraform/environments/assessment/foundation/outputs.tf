output "response_demo_secret_id" {
  description = "Secret Manager ID for the response-service demo token."
  value       = module.foundation.response_demo_secret_id
}

output "response_demo_secret_name" {
  description = "Full Secret Manager resource name for the response-service demo token."
  value       = module.foundation.response_demo_secret_name
}

output "grafana_observability_service_account_email" {
  description = "Service-account email used by the Grafana Cloud data sources."
  value       = module.foundation.grafana_observability_service_account_email
}
