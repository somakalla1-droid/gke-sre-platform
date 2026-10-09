# Secondary Cluster and Application Deployment Evidence

**Verified:** October 8, 2026 (America/Chicago)  
**Terraform root:** `terraform/environments/assessment/secondary-cluster`  
**GCP project:** `gke-sre-assesment`  
**Cluster:** `gke-secondary` in `us-east1-b`  
**Namespace:** `assessment-apps`

## Infrastructure apply and health

The reviewed saved plan completed successfully:

```text
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

Terraform created the secondary cluster, its three-node `general-purpose` pool,
the node service account, and the required IAM memberships. All three
`e2-medium` nodes were `Ready` on GKE `v1.35.8-gke.1225000` with
Container-Optimized OS and `containerd`.

The cluster uses the foundation-managed `gke-secondary-subnet` and its
secondary Pod and Service ranges in `us-east1`. Its Terraform state is isolated
under `terraform/assessment/secondary-cluster` in the protected GCS backend.

## Application releases

Both applications were installed from immutable Artifact Registry images:

| Release | Image tag | Verified state |
| --- | --- | --- |
| `response` | `02f767d7e54d` | Deployment `2/2`; two ready pods; ClusterIP Service; HPA 2–5; PDB `minAvailable: 1` |
| `request-info` | `2311689d057c` | Deployment `2/2`; two ready pods; ClusterIP Service; HPA 2–5; PDB `minAvailable: 1` |

The response release also created its ConfigMap, `response-service-workload`
Kubernetes service account, and Secret Manager CSI `SecretProviderClass`.
Secret values were neither printed nor copied into a Kubernetes Secret.

The request release uses the in-cluster response endpoint:

```text
http://response-gke-response-service.assessment-apps.svc.cluster.local
```

No external Ingress was created in the secondary cluster during this phase.
That avoids a second standalone load balancer before the multi-cluster routing
design is reviewed and implemented.

## End-to-end verification

A disposable `curlimages/curl:8.12.1` pod called Application A through its
ClusterIP Service with correlation ID `secondary-flow-001`. The returned JSON
proved the complete A-to-B path:

| Field | Application A | Application B |
| --- | --- | --- |
| Cluster | `gke-secondary` | `gke-secondary` |
| Region | `us-east1` | `us-east1` |
| Request ID | `secondary-flow-001` | `secondary-flow-001` |
| Status | HTTP `200` | `response_status_code: 200` |
| Observed A-to-B latency | `31 ms` | — |

Both applications' structured logs contained the same request ID and status
code `200`, proving DNS resolution, service discovery, downstream connectivity,
and request correlation in the secondary cluster. The disposable test pod was
removed automatically after the request.

## Connectivity observation

The first verification attempt failed before creating the test pod because the
Mac temporarily had no route to the cluster's public Kubernetes API endpoint.
The cluster remained `RUNNING`, the kubeconfig context and endpoint were
correct, and TCP port 443 became reachable on retry. No Kubernetes or
application change was required. This distinguishes local control-plane access
from an in-cluster service failure.

## Delivery boundary

This evidence completes the two-cluster and two-application deployment phase.
It does not yet prove cross-cluster ingress, geographic routing, or automatic
failover. Those controls are the next delivery phase and require a separate
review of GKE multi-cluster feature eligibility, cost, and rollback behavior.
