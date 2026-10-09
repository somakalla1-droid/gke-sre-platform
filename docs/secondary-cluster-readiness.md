# Secondary GKE Cluster Readiness

> **Status:** Applied and verified on October 8, 2026. See
> [Secondary Cluster and Application Deployment Evidence](evidence/secondary-cluster-deployment.md).

## Purpose

Create the assessment's second GKE cluster in `us-east1-b` with the same
security, networking, observability, image-pull access, and workload capacity
as the verified primary cluster.

## Reviewed configuration

| Setting | Value |
| --- | --- |
| Project | `gke-sre-assesment` |
| Cluster | `gke-secondary` |
| Zone / region | `us-east1-b` / `us-east1` |
| Subnet | `gke-secondary-subnet` |
| Pod range | `secondary-pods` |
| Service range | `secondary-services` |
| Node pool | Three `e2-medium` nodes with 30 GiB standard disks |
| Artifact Registry | `us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps` |
| Terraform state | `gs://gke-sre-assesment-tfstate-150538255871/terraform/assessment/secondary-cluster` |

The node count intentionally matches the primary cluster. The primary
deployment demonstrated that three nodes are required to schedule GKE system
components and two replicas of each assessment application with their declared
resources and disruption budgets.

## Pre-apply checks

The initial review confirmed:

- only `gke-primary` exists;
- the secondary Terraform state is empty;
- the `us-east1` E2 CPU quota is 24 vCPUs with zero usage;
- three `e2-medium` nodes require 6 vCPUs;
- the secondary subnet and alias ranges already exist in the foundation state.

After the Terraform PR is merged, create a fresh saved plan from `main`:

```bash
terraform -chdir=terraform/environments/assessment/secondary-cluster init -reconfigure

terraform -chdir=terraform/environments/assessment/secondary-cluster validate

terraform -chdir=terraform/environments/assessment/secondary-cluster plan \
  -out=secondary-cluster.tfplan
```

Review the plan before applying. It should create one cluster, one node pool,
one node service account, and the two required IAM memberships. It must not
modify or destroy primary-region resources.

## Apply and verify

```bash
terraform -chdir=terraform/environments/assessment/secondary-cluster apply \
  secondary-cluster.tfplan

gcloud container clusters get-credentials gke-secondary \
  --zone us-east1-b \
  --project gke-sre-assesment

kubectl get nodes -o wide
kubectl get pods -A

terraform -chdir=terraform/environments/assessment/secondary-cluster \
  plan -detailed-exitcode
```

Expected final plan exit code: `0`, meaning no drift.

## Deployment order after cluster verification

1. Deploy response service B and verify both replicas and its internal Service.
2. Deploy request-info service A with the secondary response-service DNS URL.
3. Verify the A to B request path inside the cluster.
4. Verify HPA, PDB, probes, ConfigMaps, and resource limits.
5. Add Secret Manager access only through Workload Identity; do not create a
   static Kubernetes Secret.
6. Continue to multi-cluster routing and failover validation.

## Cost control

The secondary cluster adds three running Compute Engine nodes and a GKE control
plane. Keep it running only while multi-cluster deployment and failover evidence
are being collected. Billing should be reviewed before and after creation, and
the cluster must be included in the final Terraform cleanup.
