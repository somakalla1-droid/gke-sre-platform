locals {
  services = toset([
    "artifactregistry.googleapis.com", "bigquery.googleapis.com",
    "clouderrorreporting.googleapis.com", "cloudprofiler.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com", "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com", "iamcredentials.googleapis.com",
    "logging.googleapis.com", "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "sts.googleapis.com",
    "telemetry.googleapis.com",
  ])

  application_observability_role_bindings = {
    for binding in setproduct(
      var.application_observability_service_accounts,
      toset([
        "roles/cloudprofiler.agent",
        "roles/cloudtrace.agent",
      ])
      ) : "${binding[0]}|${binding[1]}" => {
      service_account = binding[0]
      role            = binding[1]
    }
  }
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

resource "google_iam_workload_identity_pool" "github_actions" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Keyless CI identity pool for the assessment application repositories."

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions OIDC"
  description                        = "Trust GitHub Actions on the default branch of the assessment owner."

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_owner"    = "assertion.repository_owner"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
  }

  attribute_condition = "assertion.repository_owner_id == '${var.github_repository_owner_id}' && assertion.ref == 'refs/heads/main'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com/"
  }
}

resource "google_service_account" "github_artifact_publisher" {
  project      = var.project_id
  account_id   = "github-artifact-publisher"
  display_name = "GitHub Artifact Registry publisher"
  description  = "Keyless GitHub Actions identity scoped to publishing assessment application images."

  depends_on = [google_project_service.required]
}

resource "google_artifact_registry_repository_iam_member" "github_artifact_publisher" {
  project    = var.project_id
  location   = google_artifact_registry_repository.apps.location
  repository = google_artifact_registry_repository.apps.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_artifact_publisher.email}"
}

resource "google_service_account_iam_member" "github_artifact_publisher" {
  for_each = var.github_publisher_repositories

  service_account_id = google_service_account.github_artifact_publisher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${each.value}"
}

resource "google_compute_security_policy" "assessment_web_waf" {
  project     = var.project_id
  name        = "gke-assessment-web-waf"
  description = "Cloud Armor WAF policy for the assessment's public multi-cluster application."
  type        = "CLOUD_ARMOR"

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Block SQL injection attempts using Google's stable preconfigured rule set."

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable')"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1100
    description = "Block cross-site scripting attempts using Google's stable preconfigured rule set."

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable')"
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Allow requests that do not match a WAF deny rule."

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_bigquery_dataset" "assessment_app_logs" {
  project                     = var.project_id
  dataset_id                  = var.application_logs_dataset_id
  location                    = "US"
  delete_contents_on_destroy  = false
  default_table_expiration_ms = var.application_logs_retention_days * 24 * 60 * 60 * 1000

  labels = {
    purpose     = "assessment-observability"
    data_source = "cloud-logging"
  }

  depends_on = [google_project_service.required]
}

resource "google_logging_project_sink" "assessment_app_requests" {
  project                = var.project_id
  name                   = "assessment-app-request-logs-to-bigquery"
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.assessment_app_logs.dataset_id}"
  unique_writer_identity = true

  filter = <<-EOT
    resource.type="k8s_container"
    resource.labels.cluster_name="gke-primary"
    resource.labels.namespace_name="${var.application_namespace}"
    resource.labels.container_name="application"
    jsonPayload.message="request completed"
  EOT

  depends_on = [google_project_service.required]
}

resource "google_bigquery_dataset_iam_member" "assessment_app_requests_writer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.assessment_app_logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.assessment_app_requests.writer_identity
}

resource "google_service_account" "grafana_observability" {
  project      = var.project_id
  account_id   = "grafana-observability"
  display_name = "Grafana assessment observability"
  description  = "Read-only identity for the assessment Grafana Cloud data sources."

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "grafana_observability" {
  for_each = toset([
    "roles/bigquery.jobUser",
    "roles/monitoring.viewer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.grafana_observability.email}"
}

resource "google_bigquery_dataset_iam_member" "grafana_application_logs_reader" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.assessment_app_logs.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.grafana_observability.email}"
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

resource "google_project_iam_member" "application_observability_agents" {
  for_each = local.application_observability_role_bindings

  project = var.project_id
  role    = each.value.role
  member  = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.application_namespace}/sa/${each.value.service_account}"

  depends_on = [google_project_service.required]
}
