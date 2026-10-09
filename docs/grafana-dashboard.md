# Grafana Assessment Dashboard

## Purpose

The version-controlled dashboard at
[`grafana/dashboards/gke-sre-assessment.json`](../grafana/dashboards/gke-sre-assessment.json)
implements the four panels required by the assignment:

| Panel | Source | Signal |
| --- | --- | --- |
| Application Error Rate | BigQuery | Percentage of request-service completions with status `>= 500` |
| Pod Restart Count | Cloud Monitoring | Cumulative container restarts grouped by pod |
| Request Latency Percentiles | BigQuery | p50, p95, and p99 request-service latency |
| Application CPU and Memory | Cloud Monitoring | CPU cores and memory bytes grouped by pod |

The BigQuery panels intentionally select only pods whose names start with
`request-info-`. Both applications log a completion for the same end-to-end
request, so including both would count one customer request twice.

## Prerequisites

- The BigQuery and Google Cloud Monitoring data sources pass **Save & test**.
- The BigQuery data source uses project `gke-sre-assesment` and processing
  location `US`.
- The dashboard time range contains generated test traffic. The JSON defaults
  to the last 24 hours.
- The dashboard contains no credentials, service-account keys, or Grafana
  access tokens.

## Import after merge

1. Update the local platform repository from `main`.
2. In Grafana Cloud, select **Dashboards > New > Import**.
3. Upload `grafana/dashboards/gke-sre-assessment.json`.
4. Map **Google BigQuery** to the verified BigQuery data source.
5. Map **Google Cloud Monitoring** to the verified Cloud Monitoring data
   source.
6. Select **Import**.
7. Set the dashboard range to **Last 24 hours** and wait for all four panels to
   render.

Grafana expands `$__timeFilter(timestamp)` and
`$__timeGroup(timestamp, $__interval)` according to the selected dashboard
range. The `stdout_*` wildcard keeps the log queries valid as Cloud Logging
creates new date-sharded BigQuery tables.

## Verification

Generate one normal, one error, and one delayed request, then verify:

- Error rate shows a non-zero point for the controlled error.
- Restart count shows all application pods, normally at zero.
- Latency displays p50, p95, and p99 and reflects the controlled delay.
- CPU and memory display series for request-info and response pods.

If a BigQuery panel is empty, first widen the time range and confirm a matching
`stdout_YYYYMMDD` table exists. If a metrics panel is empty, use Grafana
Explore with the same Cloud Monitoring data source and confirm the cluster,
namespace, and container labels.

The Cloud Monitoring target includes both `promQLQuery` and the plugin's
companion `timeSeriesList` structure. Although PromQL is the active query type,
the companion structure is required to prevent Grafana's dashboard importer
from migrating the target back to the default Builder query.

## Evidence and credential cleanup

After verification:

1. Export the saved dashboard JSON and compare it with the repository copy.
2. Capture a sanitized screenshot showing all four panels and the selected
   time range.
3. Record the dashboard verification in `docs/evidence/`.
4. Delete the temporary local service-account JSON key file.
5. Revoke its Google Cloud IAM key.
6. Revoke the unused Grafana Kubernetes-onboarding access-policy token.

Do not revoke the temporary service-account key until the dashboard evidence
has been captured, because both configured Grafana data sources currently use
that key.
