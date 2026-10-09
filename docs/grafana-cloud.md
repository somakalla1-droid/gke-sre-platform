# Grafana Cloud Data-Source Setup

## Purpose

Build the assignment's cloud-hosted Grafana dashboard from data already held in
Google Cloud:

- BigQuery supplies application error-rate and request-latency panels.
- Google Cloud Monitoring supplies pod-restart, CPU, and memory panels.

The Grafana Kubernetes Monitoring collector is intentionally not installed.
GKE already exports the required telemetry to Google Cloud, so installing a
second collector would duplicate ingestion, consume cluster resources, and
introduce another non-expiring credential.

## Terraform-managed identity

The foundation module creates `grafana-observability` with only:

- `roles/bigquery.jobUser` on the project, to run query jobs.
- `roles/bigquery.dataViewer` on `assessment_app_logs` only.
- `roles/monitoring.viewer` on the project, to read Cloud Monitoring metrics.

It also enables `cloudresourcemanager.googleapis.com`, which the Grafana
BigQuery plugin requires when resolving the default project.

Terraform does **not** create a service-account key. Private key material must
never enter Terraform state, Git, shell history, documentation, or screenshots.

## Assessment authentication lifecycle

The free Grafana Cloud stack uses a temporary JSON key for the read-only
identity because the keyless Grafana Cloud Workload Identity Federation option
requires a compatible external OIDC/SSO configuration. For this time-bounded
assessment:

1. Create the key into a local temporary file only after the IAM PR is merged
   and applied.
2. Upload it directly to each Grafana data source without printing its content.
3. Verify the dashboard and capture sanitized evidence.
4. Delete the Google service-account key and the local temporary file.
5. Revoke the unused Grafana Kubernetes-onboarding access-policy token.

Production systems should use Workload Identity Federation or another
short-lived identity mechanism instead of service-account keys.

## Planned data sources

### Google BigQuery

- Default project: `gke-sre-assesment`
- Processing location: `US`
- Dataset: `assessment_app_logs`
- Maximum bytes billed: use a small guardrail appropriate to the 30-day,
  filtered assessment dataset.

### Google Cloud Monitoring

- Default project: `gke-sre-assesment`
- Authentication identity: `grafana-observability`
- Scope: read-only GKE and Kubernetes metrics.

## Required dashboard panels

1. Application error rate from BigQuery.
2. Pod restart count from Cloud Monitoring.
3. Request latency p50, p95, and p99 from BigQuery.
4. Workload CPU and memory utilization from Cloud Monitoring.

The exported dashboard JSON and a screenshot will be committed only after all
four panels return verified data.
