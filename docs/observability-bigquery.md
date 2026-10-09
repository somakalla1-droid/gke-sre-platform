# BigQuery Application-Log Export

## Purpose

Export only completed request logs from the assessment applications to BigQuery. This supports required error-rate and latency analysis without exporting broad system, secret, or control-plane logs.

## Terraform-managed resources

The foundation Terraform module creates:

- Dataset `assessment_app_logs` in multi-region `US`.
- Default table expiration of 30 days to bound storage cost.
- Project log sink `assessment-app-request-logs-to-bigquery`.
- A unique sink-writer identity with `roles/bigquery.dataEditor` on this dataset only.

The sink exports logs only when all of these are true:

```text
resource.type="k8s_container"
resource.labels.cluster_name="gke-primary"
resource.labels.namespace_name="assessment-apps"
resource.labels.container_name="application"
jsonPayload.message="request completed"
```

This includes both deployed application workloads and their structured `status_code`, `latency_ms`, and `request_id` fields. It excludes GKE system logs, secret values, and non-request application output.

## Apply sequence

After the Terraform PR is merged, create and review a fresh foundation plan, then apply it. BigQuery tables appear after new matching logs are delivered; log export is asynchronous.

Generate a public endpoint request after the sink exists:

```bash
curl --fail --silent --show-error \
  -H "X-Request-ID: bigquery-evidence-001" \
  "http://PUBLIC_IP/"
```

Do not place a real secret, credential, or token in the request ID.

## Querying exported logs

Cloud Logging creates date-suffixed tables under the dataset. Inspect the dataset before using queries:

```bash
bq ls --project_id=gke-sre-assesment assessment_app_logs
```

Replace `TABLE_NAME` with the emitted table name and run queries using the fully qualified project/dataset/table name.

### Error rate over time

```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS minute,
  COUNT(*) AS requests,
  COUNTIF(CAST(jsonPayload.status_code AS INT64) >= 500) AS errors,
  SAFE_DIVIDE(COUNTIF(CAST(jsonPayload.status_code AS INT64) >= 500), COUNT(*)) AS error_rate
FROM `gke-sre-assesment.assessment_app_logs.TABLE_NAME`
GROUP BY minute
ORDER BY minute;
```

### Request latency percentiles

```sql
SELECT
  resource.labels.cluster_name AS cluster,
  APPROX_QUANTILES(CAST(jsonPayload.latency_ms AS INT64), 100)[OFFSET(50)] AS p50_ms,
  APPROX_QUANTILES(CAST(jsonPayload.latency_ms AS INT64), 100)[OFFSET(95)] AS p95_ms,
  APPROX_QUANTILES(CAST(jsonPayload.latency_ms AS INT64), 100)[OFFSET(99)] AS p99_ms
FROM `gke-sre-assesment.assessment_app_logs.TABLE_NAME`
GROUP BY cluster;
```

### Correlated request trace

```sql
SELECT
  timestamp,
  resource.labels.pod_name AS pod,
  jsonPayload.status_code,
  jsonPayload.latency_ms
FROM `gke-sre-assesment.assessment_app_logs.TABLE_NAME`
WHERE jsonPayload.request_id = "bigquery-evidence-001"
ORDER BY timestamp;
```

## Scope note

This dataset supports BigQuery log analysis. Grafana pod restarts and CPU/memory panels should use GKE/Managed Prometheus metrics, while error-rate and latency panels can use this exported-log dataset.
