# Request-Service Deployment and Cross-Service Flow Evidence

**Verified:** October 8, 2026 (America/Chicago)  
**Cluster:** `gke-primary` in `us-central1-a`  
**Namespace:** `assessment-apps`  
**Helm release:** `request-info`  
**Source repository:** [gke-request-info-service](https://github.com/somakalla1-droid/gke-request-info-service)

## Release inputs

The request-service chart was deployed from merged `main` with immutable image tag:

```text
us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-request-info-service:2311689d057c
```

Its ConfigMap sets the internal response-service URL:

```text
http://response-gke-response-service.assessment-apps.svc.cluster.local
```

This is Kubernetes service DNS: traffic remains in the cluster and does not require an external load balancer.

## Deployment verification

Both applications were healthy after the request-service rollout:

| Workload | Verified state |
| --- | --- |
| Request deployment | `2/2` ready and available |
| Request pods | Two `Running` pods, each `1/1` ready, zero restarts |
| Response deployment | `2/2` ready and available |
| Response pods | Two `Running` pods, each `1/1` ready, zero restarts |
| Request and response Services | Internal `ClusterIP` services on port 80 |
| HPA | Both services: two to five replicas, observed `cpu: 0%/70%` |
| PDB | Both services: `minAvailable: 1` |

The primary node pool was scaled through Terraform to three `e2-medium` nodes. This provides schedulable capacity for both two-replica services after GKE system workload reservations.

## End-to-end request correlation

A temporary local-only port-forward was used to send one request to Application A with a fixed correlation ID:

```text
X-Request-ID: assessment-flow-001
```

Application A returned HTTP `200`, called Application B in `33 ms`, and included the downstream metadata and `response_status_code: 200` in its response. Both structured application logs recorded the same request ID:

```json
{"request_id":"assessment-flow-001","severity":"INFO","status_code":200}
```

The request-service log recorded `latency_ms: 33`; the response-service log recorded `latency_ms: 0` for its local request. This proves internal DNS connectivity, request-ID propagation, and correlation-ready logs without exposing either ClusterIP service publicly.

## Remaining scope

This is not yet the assessment's accessible external application endpoint, BigQuery log analysis, Grafana dashboard, or multi-cluster routing evidence. Those remain separate, explicitly tracked phases.
