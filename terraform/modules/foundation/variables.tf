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

variable "application_logs_dataset_id" {
  description = "BigQuery dataset ID for exported assessment application request logs."
  type        = string
  default     = "assessment_app_logs"
}

variable "application_logs_retention_days" {
  description = "Default BigQuery table retention period for exported application logs."
  type        = number
  default     = 30

  validation {
    condition     = var.application_logs_retention_days >= 1 && var.application_logs_retention_days <= 365
    error_message = "application_logs_retention_days must be between 1 and 365."
  }
}
