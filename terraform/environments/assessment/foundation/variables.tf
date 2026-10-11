variable "project_id" {
  type    = string
  default = "gke-sre-assesment"
}
variable "primary_region" {
  type    = string
  default = "us-central1"
}
variable "secondary_region" {
  type    = string
  default = "us-east1"
}

variable "binary_authorization_enforcement_mode" {
  description = "Action taken when an image fails the project Binary Authorization attestation rule."
  type        = string
  default     = "ENFORCED_BLOCK_AND_AUDIT_LOG"

  validation {
    condition = contains([
      "DRYRUN_AUDIT_LOG_ONLY",
      "ENFORCED_BLOCK_AND_AUDIT_LOG",
    ], var.binary_authorization_enforcement_mode)
    error_message = "binary_authorization_enforcement_mode must be DRYRUN_AUDIT_LOG_ONLY or ENFORCED_BLOCK_AND_AUDIT_LOG."
  }
}
