terraform {
  required_version = ">= 1.10, < 2.0"
  backend "gcs" {
    bucket = "gke-sre-assesment-tfstate-150538255871"
    prefix = "terraform/assessment/foundation"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }
}
provider "google" {
  project = var.project_id
  region  = var.primary_region
}
