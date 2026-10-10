data "google_compute_network" "main" {
  project = var.project_id
  name    = var.network
}

data "google_compute_subnetwork" "cluster" {
  project = var.project_id
  name    = var.subnetwork
  region  = var.region
}

data "google_artifact_registry_repository" "apps" {
  project       = var.project_id
  location      = var.artifact_registry_location
  repository_id = var.artifact_registry_repository
}

resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "${var.name} GKE nodes"
}

resource "google_project_iam_member" "nodes_default" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_artifact_registry_repository_iam_member" "nodes_reader" {
  project    = var.project_id
  location   = data.google_artifact_registry_repository.apps.location
  repository = data.google_artifact_registry_repository.apps.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  project                  = var.project_id
  name                     = var.name
  location                 = var.location
  network                  = data.google_compute_network.main.self_link
  subnetwork               = data.google_compute_subnetwork.cluster.self_link
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  deletion_protection      = false
  enable_shielded_nodes    = true
  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }
  release_channel { channel = "REGULAR" }
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  binary_authorization {
    evaluation_mode = var.binary_authorization_evaluation_mode
  }

  # Required for GKE to reconcile Kubernetes Ingress resources into external
  # Application Load Balancers. Kept explicit rather than relying on defaults.
  addons_config {
    http_load_balancing {
      disabled = false
    }
  }

  # Required before a cluster can participate in a GKE multi-cluster Gateway.
  # The standard channel installs the stable Gateway API CRDs and controller.
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  secret_manager_config {
    enabled = true

    rotation_config {
      enabled           = true
      rotation_interval = "120s"
    }
  }
}

resource "google_container_node_pool" "general_purpose" {
  project    = var.project_id
  name       = "general-purpose"
  location   = var.location
  cluster    = google_container_cluster.this.name
  node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    image_type      = "COS_CONTAINERD"
    disk_type       = var.disk_type
    disk_size_gb    = var.disk_size_gb
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    workload_metadata_config { mode = "GKE_METADATA" }
    metadata = {
      disable-legacy-endpoints = "true"
    }
    labels = { workload = "assessment" }

    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_project_iam_member.nodes_default,
    google_artifact_registry_repository_iam_member.nodes_reader,
  ]
}
