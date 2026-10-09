locals {
  services = toset([
    "dns.googleapis.com",
    "gkehub.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "trafficdirector.googleapis.com",
  ])
}

data "google_project" "current" {
  project_id = var.project_id
}

data "google_container_cluster" "primary" {
  project  = var.project_id
  name     = "gke-primary"
  location = var.primary_location
}

data "google_container_cluster" "secondary" {
  project  = var.project_id
  name     = "gke-secondary"
  location = var.secondary_location
}

resource "google_project_service" "required" {
  for_each = local.services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_gke_hub_fleet" "assessment" {
  project      = var.project_id
  display_name = "GKE SRE assessment"

  depends_on = [google_project_service.required]
}

resource "google_gke_hub_membership" "primary" {
  project       = var.project_id
  location      = var.primary_region
  membership_id = "gke-primary"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${data.google_container_cluster.primary.id}"
    }
  }

  labels = {
    environment = "assessment"
    role        = "primary"
  }

  depends_on = [google_gke_hub_fleet.assessment]
}

resource "google_gke_hub_membership" "secondary" {
  project       = var.project_id
  location      = var.secondary_region
  membership_id = "gke-secondary"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${data.google_container_cluster.secondary.id}"
    }
  }

  labels = {
    environment = "assessment"
    role        = "secondary"
  }

  depends_on = [google_gke_hub_fleet.assessment]
}

resource "google_gke_hub_feature" "multi_cluster_services" {
  project  = var.project_id
  location = "global"
  name     = "multiclusterservicediscovery"

  depends_on = [
    google_gke_hub_membership.primary,
    google_gke_hub_membership.secondary,
  ]
}

# Google requires this service agent to reconcile Gateway and backend
# resources in the member clusters. The role is prescribed by the GKE
# multi-cluster Gateway setup guide.
resource "google_project_iam_member" "multi_cluster_gateway_controller" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-multiclusteringress.iam.gserviceaccount.com"

  depends_on = [google_project_service.required]
}

resource "google_gke_hub_feature" "multi_cluster_gateway" {
  project  = var.project_id
  location = "global"
  name     = "multiclusteringress"

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.primary.id
    }
  }

  depends_on = [
    google_gke_hub_feature.multi_cluster_services,
    google_project_iam_member.multi_cluster_gateway_controller,
  ]
}
