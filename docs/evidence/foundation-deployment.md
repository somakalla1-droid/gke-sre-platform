# Foundation Deployment Evidence

**Applied:** October 7, 2026  
**Terraform root:** `terraform/environments/assessment/foundation`  
**GCP project:** `gke-sre-assesment`  
**Remote-state prefix:** `terraform/assessment/foundation`

## Purpose

The foundation layer provides shared cloud capabilities required before creating either GKE cluster. Separating it from cluster state allows networking and the container registry to remain stable while clusters are created, changed, or destroyed independently.

## Apply result

The saved and reviewed Terraform plan completed successfully:

```text
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
```

## Managed resources

Terraform state contains these 12 resources:

```text
module.foundation.google_artifact_registry_repository.apps
module.foundation.google_compute_network.main
module.foundation.google_compute_subnetwork.primary
module.foundation.google_compute_subnetwork.secondary
module.foundation.google_project_service.required["artifactregistry.googleapis.com"]
module.foundation.google_project_service.required["bigquery.googleapis.com"]
module.foundation.google_project_service.required["compute.googleapis.com"]
module.foundation.google_project_service.required["container.googleapis.com"]
module.foundation.google_project_service.required["iam.googleapis.com"]
module.foundation.google_project_service.required["iamcredentials.googleapis.com"]
module.foundation.google_project_service.required["logging.googleapis.com"]
module.foundation.google_project_service.required["monitoring.googleapis.com"]
```

## Deployed design

| Component | Configuration |
| --- | --- |
| VPC | `gke-assessment-vpc`, custom subnet mode, global dynamic routing |
| Primary subnet | `gke-primary-subnet`, `us-central1`, nodes `10.10.0.0/20` |
| Primary alias ranges | Pods `10.20.0.0/16`; Services `10.30.0.0/20` |
| Secondary subnet | `gke-secondary-subnet`, `us-east1`, nodes `10.40.0.0/20` |
| Secondary alias ranges | Pods `10.50.0.0/16`; Services `10.60.0.0/20` |
| Artifact Registry | `gke-apps`, Docker format, `us-central1` |

The node, pod, and service ranges do not overlap. The secondary ranges make both subnets ready for VPC-native GKE clusters.

## Drift verification

After the apply, Terraform refreshed every managed resource and reported:

```text
No changes. Your infrastructure matches the configuration.
```

This proves that, at verification time, the remote state, Terraform configuration, and observed Google Cloud resources agreed.

## Scope boundary

This deployment did **not** create:

- GKE clusters or nodes.
- Kubernetes workloads or Services.
- Public application endpoints or load balancers.
- BigQuery datasets or log sinks.
- Grafana resources.

Those resources are introduced in later phases so their configuration, cost, and failure behavior can be reviewed separately.

## Reverification commands

```bash
terraform -chdir=terraform/environments/assessment/foundation state list

terraform \
  -chdir=terraform/environments/assessment/foundation \
  plan -detailed-exitcode
```

For the detailed-exit-code plan, exit code `0` means no changes, `2` means changes are present, and `1` means Terraform encountered an error.
