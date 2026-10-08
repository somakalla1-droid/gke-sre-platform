# Response-Service Capacity Incident

**Date:** October 8, 2026 (America/Chicago)  
**Cluster:** `gke-primary` (`us-central1-a`)  
**Application:** `gke-response-service`  
**Severity:** Assessment deployment blocker; no customer traffic was exposed.

## What happened

The first Helm release of the two-replica response service did not become ready within the five-minute deployment timeout. Helm used rollback-on-failure, so it correctly removed the incomplete release rather than leaving a partial deployment.

## Evidence and diagnosis

Kubernetes events showed both application pods as unschedulable:

```text
0/1 nodes are available: 1 Insufficient cpu.
```

The primary cluster had one `e2-medium` node. Its allocatable CPU was `940m`; existing GKE system workloads requested `938m` (99%). The Secret Manager CSI integration was not the failure: the node carried `iam.gke.io/gke-metadata-server-enabled=true`, and the pods never reached image pull or secret-mount execution because they could not be scheduled.

## Remediation

The primary Terraform root sets `node_count = 2` for the `general-purpose` node pool. This preserves Terraform as the source of truth and creates enough schedulable capacity for the two-replica application while retaining the existing `e2-medium` assessment machine type.

The correction is intentionally limited to the primary cluster. The secondary cluster remains uncreated and unchanged until the primary application deployment is stable, avoiding unnecessary free-trial cost.

## Prevention and verification

Before deploying additional workloads, check capacity as well as node health:

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl get events -A --sort-by=.lastTimestamp
```

The two-node Terraform change was applied and drift-verified. The retry then exposed a second, independent startup control: Kubernetes rejected the distroless image's named `nonroot` user because it could not verify that it was non-root. The response-service Helm chart was corrected to set numeric `runAsUser` and `runAsGroup` values of `65532`, then merged before a final retry.

The final Helm release succeeded. Two response pods were `Running`, `Ready`, and at zero restarts. They were scheduled to the second node, pulled the immutable Artifact Registry image, and used the configured Secret Manager CSI volume. The full evidence is recorded in [response-service-deployment.md](response-service-deployment.md).
