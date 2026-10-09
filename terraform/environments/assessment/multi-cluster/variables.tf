variable "project_id" {
  description = "GCP project that owns the fleet and both GKE clusters."
  type        = string
  default     = "gke-sre-assesment"
}

variable "primary_region" {
  description = "Region containing the primary config-cluster membership."
  type        = string
  default     = "us-central1"
}

variable "primary_location" {
  description = "Zone containing the primary GKE cluster."
  type        = string
  default     = "us-central1-a"
}

variable "secondary_region" {
  description = "Region containing the secondary fleet membership."
  type        = string
  default     = "us-east1"
}

variable "secondary_location" {
  description = "Zone containing the secondary GKE cluster."
  type        = string
  default     = "us-east1-b"
}
