variable "project_id" { type = string }
variable "primary_region" { type = string }
variable "secondary_region" { type = string }

variable "application_namespace" {
  description = "Namespace that contains assessment application workloads."
  type        = string
  default     = "assessment-apps"
}

variable "response_service_account_name" {
  description = "Kubernetes service account granted access to the response-service demo secret."
  type        = string
  default     = "response-service-workload"
}

variable "response_demo_secret_id" {
  description = "Secret Manager secret ID for the response-service demonstration token."
  type        = string
  default     = "gke-sre-response-demo-token"
}
