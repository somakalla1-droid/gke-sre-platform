locals {
  services = toset([
    "connectgateway.googleapis.com",
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

  authority {
    issuer = "https://container.googleapis.com/v1/${data.google_container_cluster.primary.id}"
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

  authority {
    issuer = "https://container.googleapis.com/v1/${data.google_container_cluster.secondary.id}"
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

# The fleet MCS importer discovers network endpoints and requires read-only
# network visibility in the fleet host project. Both clusters already use the
# fleet host project's GKE Workload Identity pool.
resource "google_project_iam_member" "mcs_importer_network_viewer" {
  project = var.project_id
  role    = "roles/compute.networkViewer"
  member  = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/gke-mcs/sa/gke-mcs-importer"

  depends_on = [google_gke_hub_feature.multi_cluster_services]
}

# API enablement does not guarantee that the Google-managed controller service
# agent already exists when Terraform reaches the IAM resource. Materialize the
# identity explicitly so the IAM binding has a concrete dependency and member.
resource "google_project_service_identity" "multi_cluster_gateway_controller" {
  provider = google-beta

  project = var.project_id
  service = "multiclusteringress.googleapis.com"

  depends_on = [google_project_service.required]
}

# Google requires this service agent to reconcile Gateway and backend
# resources in the member clusters. The role is prescribed by the GKE
# multi-cluster Gateway setup guide.
resource "google_project_iam_member" "multi_cluster_gateway_controller" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = google_project_service_identity.multi_cluster_gateway_controller.member
}

# API enablement materializes the service identity but does not guarantee that
# its product-specific service-agent role is bound. This role contains the
# Connect Gateway and load-balancer permissions used by the hosted controller.
resource "google_project_iam_member" "multi_cluster_gateway_service_agent" {
  project = var.project_id
  role    = "roles/multiclusteringress.serviceAgent"
  member  = google_project_service_identity.multi_cluster_gateway_controller.member
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
    google_project_iam_member.multi_cluster_gateway_service_agent,
  ]
}
