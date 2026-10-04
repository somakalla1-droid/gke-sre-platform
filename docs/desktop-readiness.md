# Desktop and Google Cloud Readiness

**Assessment date:** October 3, 2026  
**Status:** Cloud and local toolchain bootstrap complete

## Purpose

This runbook records the workstation and Google Cloud prerequisites for the GKE SRE assessment. It provides a reproducible readiness check without storing credentials, access tokens, service-account keys, or billing account identifiers in source control.

## Google Cloud baseline

| Item | Value | Status |
| --- | --- | --- |
| Authenticated user | Personal GCP administrator account | Verified locally; intentionally omitted from public documentation |
| Project name | `GKE-SRE-ASSESMENT` | Verified |
| Project ID | `gke-sre-assesment` | Verified |
| Billing | Enabled | Verified |
| Free Trial | $300 credit; $0 used when verified | Verified |
| Trial expiration | January 2, 2027 | Verified in Cloud Console |
| Monthly budget | $25 USD | Configured |
| Budget thresholds | 25%, 50%, 75%, and 100% | Configured |

> The project ID intentionally contains the spelling `assesment`. Google Cloud project IDs cannot be renamed after creation.

The local `gcloud` configuration and Application Default Credentials quota project are set to `gke-sre-assesment`.

## Enabled Google Cloud services

The initial bootstrap enabled the APIs required to develop the assessment:

- Artifact Registry
- BigQuery
- Cloud Logging
- Cloud Monitoring
- Cloud Profiler
- Cloud Resource Manager
- Cloud Trace
- Compute Engine
- Google Kubernetes Engine
- IAM and IAM Credentials
- Service Usage
- Cloud Billing Budget

Enabling an API does not by itself create a billable workload. No GKE cluster, node pool, load balancer, VM, database, or other compute resource was created during readiness setup.

## Local toolchain

| Tool | Observed version/state | Status |
| --- | --- | --- |
| Google Cloud CLI | `587.0.0` | Ready |
| `kubectl` | `v1.36.1`, Darwin ARM64 | Ready |
| Docker CLI and daemon | `29.8.1` | Ready |
| GitHub CLI | `2.97.0` | Ready |
| Git | `2.50.1` | Ready |
| Terraform | `1.16.4` | Ready |
| GKE auth plugin | Installed; binary reports `v0.1.0-gke.3-75-ge286783f0` | Ready |
| Go | `1.27.1` | Ready |
| Helm | `4.3.0` | Ready |

## Workstation installation record

Terraform and the GKE authentication plugin were installed with:

```bash
brew install terraform
gcloud components install gke-gcloud-auth-plugin
```

The plugin executable was installed inside the Google Cloud SDK. A symbolic link was added to `/opt/homebrew/bin` so that `kubectl` can find it on `PATH`:

```bash
ln -s /opt/homebrew/share/google-cloud-sdk/bin/gke-gcloud-auth-plugin \
  /opt/homebrew/bin/gke-gcloud-auth-plugin
```

Docker Desktop was started and the daemon was verified with:

```bash
open -a Docker
docker info
```

Run the final tool verification:

```bash
gcloud version
kubectl version --client
terraform version
docker version
gke-gcloud-auth-plugin --version
gh version
git --version
```

## Google Cloud verification commands

These commands are safe to rerun and do not create resources:

```bash
gcloud auth list
gcloud config get-value project
gcloud projects describe gke-sre-assesment
gcloud billing projects describe gke-sre-assesment
gcloud services list --enabled --project=gke-sre-assesment
```

The expected default project is:

```text
gke-sre-assesment
```

## Cost and safety controls

- The project has a $25 monthly alerting budget.
- Budget alerts notify account administrators but do **not** automatically stop spending.
- Zonal clusters should be used instead of regional clusters for the assessment.
- The second cluster should exist only while multi-cluster behavior is being tested.
- Terraform-managed resources must be destroyed after evidence is collected.
- Cloud SQL, Memorystore, Cloud Armor, service mesh, and GKE Backup should remain out of the deployed free-trial scope unless explicitly required.
- Secrets, tokens, credentials, Terraform state, and billing identifiers must never be committed to Git.

## Known administrative item

An additional empty project, `gke-sre-somakalla-2026`, was created during project-ID reconciliation. It contains no GKE or compute workload. Deleting it is a separate destructive administrative action and requires explicit approval.

## Readiness exit criteria

Desktop readiness is fully complete when all of the following are true:

- [x] Google Cloud CLI is authenticated.
- [x] The intended project is selected.
- [x] Billing is enabled.
- [x] A monthly alerting budget is configured.
- [x] Required Google Cloud APIs are enabled.
- [x] `kubectl`, Git, GitHub CLI, and Docker CLI are installed.
- [x] Terraform is installed.
- [x] The GKE authentication plugin is installed and available on `PATH`.
- [x] The Docker daemon responds to `docker info`.
