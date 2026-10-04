# Configuration Inventory

**Collected:** October 3, 2026  
**Purpose:** Record verified configuration and outstanding decisions for the GKE SRE assessment without committing credentials or sensitive billing data.

## Status legend

- **Verified** — observed directly through the relevant CLI.
- **Proposed** — recommended value that has not been created or applied.
- **Pending** — required information or action is incomplete.

## Google Cloud project

| Setting | Value | Status |
| --- | --- | --- |
| Project name | `GKE-SRE-ASSESMENT` | Verified |
| Project ID | `gke-sre-assesment` | Verified |
| Project number | `150538255871` | Verified |
| Lifecycle | `ACTIVE` | Verified |
| Billing | Enabled | Verified |
| Budget | `$25 USD` monthly | Verified |
| Alert thresholds | 25%, 50%, 75%, and 100% | Verified |
| Default region | `us-central1` | Proposed |
| Default zone | `us-central1-a` | Proposed |
| Secondary region | `us-east1` | Proposed |
| Secondary zone | `us-east1-b` | Proposed |

The authenticated GCP account and billing account identifier are intentionally not stored in this repository. They can be verified locally with:

```bash
gcloud auth list
gcloud billing projects describe gke-sre-assesment
```

### Verified enabled APIs

- `artifactregistry.googleapis.com`
- `bigquery.googleapis.com`
- `billingbudgets.googleapis.com`
- `cloudprofiler.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `cloudtrace.googleapis.com`
- `compute.googleapis.com`
- `container.googleapis.com`
- `iam.googleapis.com`
- `iamcredentials.googleapis.com`
- `logging.googleapis.com`
- `monitoring.googleapis.com`
- `serviceusage.googleapis.com`

### Cloud configuration still to define

| Setting | Proposed approach | Status |
| --- | --- | --- |
| VPC name | `gke-assessment-vpc` | Proposed |
| Primary subnet | `gke-primary-subnet` | Proposed |
| Secondary subnet | `gke-secondary-subnet` | Proposed |
| Primary cluster | `gke-primary` | Proposed |
| Secondary cluster | `gke-secondary` | Proposed |
| Artifact Registry repository | `gke-apps` | Proposed |
| Terraform state bucket | Globally unique name derived from project ID | Pending creation |
| BigQuery dataset | `gke_observability` | Proposed |
| Log sink | `gke-bigquery-sink` | Proposed |

IP ranges, node/compute class, cluster release channel, and exact resource limits will be selected during Terraform design after checking quota and cost implications.

## GitHub account

| Setting | Value | Status |
| --- | --- | --- |
| GitHub host | `github.com` | Verified |
| Owner | `somakalla1-droid` | Verified |
| Authentication | GitHub CLI using system keyring | Verified |
| Git protocol | HTTPS | Verified |
| Required repository permission | `repo` scope | Verified |
| Local Git branch | `main` | Verified |
| Local Git author name | `Soma Kalla` | Verified |
| Local Git author email | GitHub `noreply` address | Verified |
| Current workspace remote | None | Pending repository association |

Tokens and token values must never appear in documentation, terminal captures, issues, commits, or CI variables printed to logs.

## Repository inventory

The three final GitHub repositories were verified after creation. All are public and use `main` as the default branch.

### Platform infrastructure

| Setting | Value | Status |
| --- | --- | --- |
| Repository | `gke-sre-platform` | Verified |
| URL | `https://github.com/somakalla1-droid/gke-sre-platform` | Verified |
| Default branch | `main` | Verified |
| Visibility | Public | Verified |
| Local directory | `/Users/somakalla/Documents/ChatGPT/GKE-SRE` | Verified workspace |
| Ownership | Platform/SRE | Proposed |

Expected contents:

- Terraform root modules and reusable modules.
- Cluster/platform Kubernetes resources.
- Logging, BigQuery, and Grafana configuration.
- Architecture, setup, operations, security, DR, troubleshooting, and evidence documentation.
- CI checks for Terraform formatting, validation, linting, and security.

### Web Application A

| Setting | Value | Status |
| --- | --- | --- |
| Repository | `gke-request-info-service` | Verified |
| URL | `https://github.com/somakalla1-droid/gke-request-info-service` | Verified |
| Default branch | `main` | Verified |
| Visibility | Public | Verified |
| Local directory | `/Users/somakalla/Documents/ChatGPT/gke-request-info-service` | Proposed |
| Ownership | Application Team A | Proposed |
| Runtime/language | To be selected | Pending |

Expected contents:

- Application source and tests.
- Dockerfile and local development instructions.
- Health, readiness, metrics, controlled-error, and latency-test endpoints.
- Helm chart or Kubernetes application manifests.
- GitHub Actions test/build/publish workflow.

### Web Application B

| Setting | Value | Status |
| --- | --- | --- |
| Repository | `gke-response-service` | Verified |
| URL | `https://github.com/somakalla1-droid/gke-response-service` | Verified |
| Default branch | `main` | Verified |
| Visibility | Public | Verified |
| Local directory | `/Users/somakalla/Documents/ChatGPT/gke-response-service` | Proposed |
| Ownership | Application Team B | Proposed |
| Runtime/language | To be selected | Pending |

Expected contents mirror Application A but retain an independent build, image, version, deployment, and release lifecycle.

## CI/CD identity model

Use keyless GitHub Actions authentication through Google Cloud Workload Identity Federation.

| Component | Proposed configuration | Status |
| --- | --- | --- |
| Workload Identity Pool | Dedicated GitHub Actions pool | Pending |
| Identity Provider | GitHub OIDC provider restricted by repository | Pending |
| Platform deployer service account | Terraform plan/apply permissions | Pending |
| App A publisher service account | Artifact Registry write for App A | Pending |
| App B publisher service account | Artifact Registry write for App B | Pending |
| Static service-account keys | Prohibited | Policy decision |

Production deployment approval should be separate from image build/publish permissions. For the assessment, infrastructure deployment remains manually approved.

## Local workstation inventory

| Component | State | Status |
| --- | --- | --- |
| Google Cloud CLI | Installed | Verified |
| `kubectl` | Installed | Verified |
| Docker CLI | Installed | Verified |
| Docker daemon | Running; server `29.8.1` | Verified |
| Terraform | `1.16.4` | Verified |
| GKE auth plugin | Installed and available on `PATH` | Verified |
| GitHub CLI | Installed and authenticated | Verified |
| Git | Installed | Verified |

See [Desktop and Google Cloud Readiness](desktop-readiness.md) for versions and completion commands.

## Decisions required before repository creation

1. Select the implementation language for both applications. Using the same language reduces assessment overhead; different languages demonstrate platform neutrality but increase maintenance.
2. Confirm the proposed primary and secondary GCP regions.
3. Decide whether both applications will own Helm charts or plain Kubernetes/Kustomize manifests.

## Verification commands

```bash
# Google Cloud
gcloud config list
gcloud projects describe gke-sre-assesment
gcloud billing projects describe gke-sre-assesment
gcloud services list --enabled --project=gke-sre-assesment

# GitHub
gh auth status
gh api user --jq '{login: .login, name: .name}'
gh repo list --limit 200

# Local Git
git config --get user.name
git config --get user.email
git branch --show-current
git remote -v
```
