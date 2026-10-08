# Primary GKE Cluster Deployment Evidence

**Applied:** October 7, 2026 (America/Chicago)  
**Terraform root:** `terraform/environments/assessment/primary-cluster`  
**GCP project:** `gke-sre-assesment`  
**Cluster:** `gke-primary` in `us-central1-a`

## Apply result

The reviewed saved plan completed successfully:

```text
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

Terraform created:

1. `gke-primary-nodes` custom node service account.
2. The Kubernetes Engine Default Node Service Account IAM binding.
3. The repository-scoped Artifact Registry Reader IAM binding.
4. The `gke-primary` zonal Standard cluster.
5. The `general-purpose` one-node pool.

## Kubernetes connectivity and health

`gcloud container clusters get-credentials` generated a local kubeconfig entry for `gke-primary`.

The node is healthy:

| Property | Observed value |
| --- | --- |
| Node status | `Ready` |
| Node pool | `general-purpose` |
| Machine type | `e2-medium` |
| GKE version | `v1.35.8-gke.1225000` |
| Internal IP | `10.10.0.4` |
| Node image | Container-Optimized OS |
| Container runtime | `containerd://2.2.7` |

The GKE system workloads were running across `gke-managed-cim`, `gmp-system`, and `kube-system`, including DNS, metrics server, fluentbit logging, the GKE metrics agent, metadata server, networking, and kube-proxy. All observed system workloads were `Running` with zero restarts.

## Terraform state and drift verification

The primary-cluster backend now contains the following eight entries:

- Three foundation data lookups: VPC, primary subnet, and Artifact Registry repository.
- Five managed resources: node service account, two IAM bindings, cluster, and node pool.

The post-apply refresh plan reported:

```text
No changes. Your infrastructure matches the configuration.
```

## Assessment scope note

The node has an external IP because this assessment uses a public-node, non-private GKE configuration to avoid a Cloud NAT dependency during the initial hands-on phase. This is an intentional cost and accessibility trade-off, not the recommended production network posture. Private nodes, controlled egress, and control-plane access restrictions remain production recommendations.

## Not yet deployed

This evidence does not yet demonstrate application workloads, an external application endpoint, the secondary cluster, BigQuery, Grafana, or multi-cluster routing. Those are separate assessment phases.
