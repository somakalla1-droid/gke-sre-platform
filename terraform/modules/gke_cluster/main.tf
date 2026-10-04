resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "${var.name} GKE nodes"
}

resource "google_container_cluster" "this" {
  project                  = var.project_id
  name                     = var.name
  location                 = var.location
  network                  = var.network
  subnetwork               = var.subnetwork
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  deletion_protection      = false
  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }
  release_channel { channel = "REGULAR" }
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}

resource "google_container_node_pool" "small" {
  project    = var.project_id
  name       = "small-general-purpose"
  location   = var.location
  cluster    = google_container_cluster.this.name
  node_count = 1
  node_config {
    machine_type    = "e2-small"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    workload_metadata_config { mode = "GKE_METADATA" }
    labels = { workload = "assessment" }
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
