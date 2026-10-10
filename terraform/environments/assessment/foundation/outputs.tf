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

output "cloud_armor_policy_name" {
  description = "Cloud Armor policy to attach to the public multi-cluster ServiceImport."
  value       = module.foundation.cloud_armor_policy_name
}

output "github_actions_workload_identity_provider" {
  description = "Full provider resource name used by google-github-actions/auth."
  value       = module.foundation.github_actions_workload_identity_provider
}

output "github_artifact_publisher_service_account_email" {
  description = "Keyless GitHub Actions service account scoped to publishing application images."
  value       = module.foundation.github_artifact_publisher_service_account_email
}

output "binary_authorization_attestor_name" {
  description = "Full Binary Authorization attestor resource name required by the project policy."
  value       = module.foundation.binary_authorization_attestor_name
}

output "binary_authorization_kms_key_version" {
  description = "Cloud KMS asymmetric signing key version associated with the attestor."
  value       = module.foundation.binary_authorization_kms_key_version
}

output "binary_authorization_enforcement_mode" {
  description = "Current Binary Authorization policy mode; audit rollout must remain DRYRUN_AUDIT_LOG_ONLY."
  value       = module.foundation.binary_authorization_enforcement_mode
}
