# BigQuery Application-Log Export Evidence

**Verified:** October 8, 2026 (America/Chicago)  
**GCP project:** `gke-sre-assesment`  
**Dataset:** `assessment_app_logs`  
**Sink:** `assessment-app-request-logs-to-bigquery`

## Deployment result

The reviewed foundation Terraform plan was applied after its pull request was
merged:

```text
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

Terraform state contains the dataset, Logging sink, and dataset IAM member. A
post-apply plan returned `No changes`, proving that the configuration and live
resources agree.

The sink uses a unique writer identity and has `roles/bigquery.dataEditor` only
on this dataset. Its filter accepts completed structured request logs from the
`application` containers in `assessment-apps` on `gke-primary`; it does not
export broad cluster or system logs.

## Controlled traffic

Three requests were sent through the public GKE Ingress with non-sensitive,
explicit request IDs:

| Request ID | Purpose | HTTP result |
| --- | --- | --- |
| `bigquery-success-001` | Application A to Application B success | `200` |
| `bigquery-error-001` | Controlled application error | `500` |
| `bigquery-delay-001` | Controlled 250 ms latency | `200` |

Cloud Logging created BigQuery table `stdout_20261009`. The success request
produced two records because both Application A and Application B log the same
correlated request ID. The error and delay routes each produced one
Application A record, for four exported rows total.

## Query evidence

The correlation query returned the expected request IDs, pod names, status
codes, and latencies. The aggregate query over those four records returned:

| Requests | Errors | Error rate | p50 | p95 | p99 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 1 | 25% | 1 ms | 250 ms | 250 ms |

This small controlled sample proves the fields and queries work; it is not a
production performance baseline. The reusable SQL is maintained in
[BigQuery application-log export](../observability-bigquery.md).

## Cost and retention controls

- Only the narrow application request-log filter is exported.
- Dataset tables expire after 30 days by default.
- Queries should use the current date-suffixed table to avoid unnecessary scan
  volume.
