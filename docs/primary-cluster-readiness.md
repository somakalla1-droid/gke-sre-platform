# Primary GKE Cluster Readiness

**Prepared:** October 7, 2026  
**Terraform root:** `terraform/environments/assessment/primary-cluster`  
**State prefix:** `terraform/assessment/primary-cluster`  
**Deployment status:** Plan reviewed; not applied

## Purpose

The primary cluster is the first billable runtime layer. It will be created and validated before application images are published or before the secondary cluster is created. This order confines troubleshooting to one cluster and avoids duplicating compute cost while the deployment process is still being proven.

## Planned cluster

| Setting | Value |
| --- | --- |
| Cluster | `gke-primary` |
| Zone | `us-central1-a` |
| VPC | Existing `gke-assessment-vpc` |
| Subnet | Existing `gke-primary-subnet` |
| Pod range | Existing `primary-pods` |
| Service range | Existing `primary-services` |
| Mode | Standard, zonal, VPC-native |
| Release channel | Regular |
| Node pool | `general-purpose` |
| Node count | 1, fixed |
| Machine type | `e2-medium` |
| Node image | Container-Optimized OS with containerd |
| Boot disk | 30 GiB `pd-standard` |
| Node identity | Custom `gke-primary-nodes` service account |
| Workload identity | Workload Identity Federation for GKE |

One node is an assessment cost decision, not a production high-availability design. Multiple application replicas can demonstrate Kubernetes process-level recovery, but they cannot survive loss of the only node. Cross-cluster recovery and the documented production design address the broader availability requirement.

## Foundation checks

The module reads the existing VPC, subnet, and Artifact Registry repository as Terraform data sources. Planning fails before cluster creation if any of those dependencies cannot be found. The cluster uses the foundation resources without duplicating ownership in the cluster state.

## Node permissions

The custom node service account receives:

- `roles/container.defaultNodeServiceAccount` at project scope for required GKE node telemetry.
- `roles/artifactregistry.reader` on only the `gke-apps` repository for private image pulls.

Application workloads do not inherit permission to other Google Cloud services from the node identity. Workload-specific cloud access will use Kubernetes service accounts and Workload Identity Federation for GKE.

## Security and operations

- Shielded GKE nodes are enabled.
- Secure Boot and integrity monitoring are enabled on the node pool.
- Legacy instance metadata endpoints are disabled.
- The node pool uses the `cloud-platform` OAuth scope while IAM roles constrain authorization.
- Node auto-repair and auto-upgrade are enabled.
- Cluster deletion protection is disabled deliberately so assessment resources can be cleaned up through Terraform.

## State status

The GCS backend initialized successfully. Before the first apply, `terraform state list` returned no resources. That is expected: backend initialization does not create infrastructure or manually write a cluster state snapshot. Terraform will write and version the state automatically during the first successful apply.

## Validation completed

```text
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/assessment/primary-cluster validate
terraform -chdir=terraform/environments/assessment/secondary-cluster validate
```

Both cluster roots are valid. The secondary root was validated because it consumes the same reusable GKE module; it has not been initialized, planned, or applied as part of this milestone.

## Next checkpoint

The primary-cluster plan was saved successfully as `primary-cluster.tfplan`. The plan resolved the existing VPC, primary subnet, and Artifact Registry repository, then proposed:

```text
Plan: 5 to add, 0 to change, 0 to destroy.
```

The five proposed resources are:

1. Custom `gke-primary-nodes` service account.
2. Project-level Kubernetes Engine Default Node Service Account role binding.
3. Repository-level Artifact Registry Reader role binding.
4. Zonal `gke-primary` cluster.
5. One-node `general-purpose` node pool.

The outputs will expose the cluster name, cluster location, and node service-account email. The saved binary plan is matched by `*.tfplan` in `.gitignore` and is not included in Git status.

## Accepted assessment limitations

- The one-node pool demonstrates pod scheduling and process recovery but not node-level high availability.
- The cluster uses the default public control-plane endpoint so the local workstation can administer it without a VPN or bastion. Access still requires Google Cloud IAM and Kubernetes authorization. A private endpoint and authorized network restrictions are documented as production hardening.
- The node is not Spot or preemptible so hands-on exercises are not interrupted unexpectedly.
- Node autoscaling remains disabled to prevent unplanned compute cost; pod autoscaling demonstrations remain bounded by the single node's allocatable capacity.

## Apply checkpoint

The reviewed saved plan can be applied with:

```bash
terraform \
  -chdir=terraform/environments/assessment/primary-cluster \
  apply \
  primary-cluster.tfplan
```

Applying creates billable GKE and Compute Engine resources. Do not regenerate the plan unless the configuration or cloud environment changes; applying the reviewed file ensures Terraform executes exactly the reviewed actions.
