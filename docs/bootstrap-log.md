# Bootstrap Log

## October 3, 2026

- Verified the GCP project, billing status, budget, and enabled APIs.
- Installed Terraform `1.16.4`, Go `1.27.1`, and Helm `4.3.0`.
- Installed the GKE authentication plugin and placed it on `PATH`.
- Started Docker Desktop and verified server `29.8.1`.
- Configured project-scoped Git identity with a GitHub `noreply` email.
- Connected this workspace to `somakalla1-droid/gke-sre-platform`.
- Cloned both application repositories as sibling directories.
- Added and locally validated both Go services, Helm charts, containers, and CI foundations.
- Added initial Terraform state boundaries and reusable foundation/GKE modules.
- Ran `terraform fmt` and validated the foundation, primary-cluster, and secondary-cluster roots with Google provider `7.46.1`.
- Built both application containers locally and validated both Go test suites and Helm charts.

No GKE cluster, VM, load balancer, database, or other billable workload was created during bootstrap.

## October 7, 2026

- Created `gke-sre-assesment-tfstate-150538255871` in `us-central1` for Terraform remote state.
- Enforced uniform bucket-level access and public-access prevention.
- Enabled object versioning; GCP also reports seven-day soft-delete protection.
- Added separate GCS backend prefixes for foundation, primary-cluster, and secondary-cluster state.
- Applied the reviewed foundation plan: 12 resources added, 0 changed, and 0 destroyed.
- Enabled eight Terraform-managed Google Cloud APIs.
- Created the custom global-routing VPC and the primary and secondary VPC-native subnets.
- Created the regional `gke-apps` Docker Artifact Registry repository in `us-central1`.
- Confirmed all 12 resources are tracked in the foundation state.
- Ran a post-apply refresh plan; Terraform reported no changes and no drift.

The foundation layer now exists in Google Cloud. No GKE cluster, node, application workload, ingress, or external load balancer has been created yet.

- Prepared the shared GKE module for a custom least-privilege node service account.
- Added the required GKE node role and repository-scoped image-pull permission.
- Changed the assessment node profile to one `e2-medium` node with a 30 GiB standard persistent boot disk.
- Added explicit lookups for the deployed VPC, subnet, and Artifact Registry repository.
- Enabled Shielded GKE nodes, Secure Boot, integrity monitoring, and disabled legacy metadata endpoints.
- Added cluster name, location, and node service-account outputs to both cluster roots.
- Formatted the Terraform and validated both cluster roots successfully.
- Initialized the primary-cluster GCS backend and confirmed that its state is empty before first apply.
- Generated and reviewed the primary-cluster saved plan: 5 resources to add, 0 to change, and 0 to destroy.
- Confirmed that the VPC, subnet, and Artifact Registry data lookups all resolved to the deployed foundation.
- Confirmed that `primary-cluster.tfplan` is excluded from Git by the `*.tfplan` ignore rule.
