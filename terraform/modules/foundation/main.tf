locals {
  services = toset([
    "artifactregistry.googleapis.com", "bigquery.googleapis.com",
    "compute.googleapis.com", "container.googleapis.com",
    "iam.googleapis.com", "iamcredentials.googleapis.com",
    "logging.googleapis.com", "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
  ])
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_service" "required" {
  for_each           = local.services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "gke-assessment-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.required]
}

resource "google_compute_subnetwork" "primary" {
  project       = var.project_id
  name          = "gke-primary-subnet"
  region        = var.primary_region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.10.0.0/20"
  secondary_ip_range {
    range_name    = "primary-pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "primary-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

resource "google_compute_subnetwork" "secondary" {
  project       = var.project_id
  name          = "gke-secondary-subnet"
  region        = var.secondary_region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.40.0.0/20"
  secondary_ip_range {
    range_name    = "secondary-pods"
    ip_cidr_range = "10.50.0.0/16"
  }
  secondary_ip_range {
    range_name    = "secondary-services"
    ip_cidr_range = "10.60.0.0/20"
  }
}

resource "google_artifact_registry_repository" "apps" {
  project       = var.project_id
  location      = var.primary_region
  repository_id = "gke-apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.required]
}

resource "google_secret_manager_secret" "response_demo_token" {
  project   = var.project_id
  secret_id = var.response_demo_secret_id

  labels = {
    application = "gke-response-service"
    purpose     = "assessment-demo"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_iam_member" "response_demo_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.response_demo_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.application_namespace}/sa/${var.response_service_account_name}"
}
