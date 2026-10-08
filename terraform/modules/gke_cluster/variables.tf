variable "project_id" {
  description = "Google Cloud project that contains the cluster and its foundation resources."
  type        = string
}

variable "name" {
  description = "GKE cluster name."
  type        = string
}

variable "location" {
  description = "Zone in which to create the assessment cluster."
  type        = string
}

variable "region" {
  description = "Region that contains the cluster subnetwork."
  type        = string
}

variable "network" {
  description = "Name of the existing foundation VPC."
  type        = string
}

variable "subnetwork" {
  description = "Name of the existing regional cluster subnetwork."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the subnet secondary range allocated to Pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet secondary range allocated to Services."
  type        = string
}

variable "artifact_registry_location" {
  description = "Location of the existing Docker Artifact Registry repository."
  type        = string
}

variable "artifact_registry_repository" {
  description = "ID of the existing Docker Artifact Registry repository."
  type        = string
}

variable "machine_type" {
  description = "Compute Engine machine type for the assessment node pool."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Fixed number of nodes in the assessment node pool."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "disk_type" {
  description = "Persistent disk type used for each GKE node boot disk."
  type        = string
  default     = "pd-standard"
}

variable "disk_size_gb" {
  description = "Boot disk size, in GiB, for each GKE node."
  type        = number
  default     = 30

  validation {
    condition     = var.disk_size_gb >= 30
    error_message = "disk_size_gb must be at least 30 GiB for this assessment."
  }
}
