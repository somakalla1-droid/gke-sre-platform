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
| Primary region | `us-central1` | Verified deployment |
| Default zone | `us-central1-a` | Proposed |
| Secondary region | `us-east1` | Verified deployment |
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

### Cloud resource configuration

| Setting | Value | Status |
| --- | --- | --- |
| VPC name | `gke-assessment-vpc` | Verified |
| VPC routing mode | Global | Verified |
| Primary subnet | `gke-primary-subnet`, `us-central1`, `10.10.0.0/20` | Verified |
| Primary pod range | `primary-pods`, `10.20.0.0/16` | Verified |
| Primary service range | `primary-services`, `10.30.0.0/20` | Verified |
| Secondary subnet | `gke-secondary-subnet`, `us-east1`, `10.40.0.0/20` | Verified |
| Secondary pod range | `secondary-pods`, `10.50.0.0/16` | Verified |
| Secondary service range | `secondary-services`, `10.60.0.0/20` | Verified |
| Primary cluster | `gke-primary`, `us-central1-a`, one `e2-medium` node | Verified deployment |
| Secondary cluster | `gke-secondary`, `us-east1-b`, one `e2-medium` node | Configured; not applied |
| Artifact Registry repository | `gke-apps`, Docker, `us-central1` | Verified |
| Terraform state bucket | `gke-sre-assesment-tfstate-150538255871` | Verified |
| BigQuery dataset | `gke_observability` | Proposed |
| Log sink | `gke-bigquery-sink` | Proposed |

The state bucket uses uniform bucket-level access, enforced public-access prevention, object versioning, and GCP soft-delete protection. Each Terraform root uses a distinct object prefix.

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
| Current workspace remote | `https://github.com/somakalla1-droid/gke-sre-platform.git` | Verified |

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
| Local directory | `/Users/somakalla/Documents/ChatGPT/gke-request-info-service` | Verified |
| Ownership | Application Team A | Proposed |
| Runtime/language | Go | Verified |

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
| Local directory | `/Users/somakalla/Documents/ChatGPT/gke-response-service` | Verified |
| Ownership | Application Team B | Proposed |
| Runtime/language | Go | Verified |

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
| Go | `1.27.1` | Verified |
| Helm | `4.3.0` | Verified |

See [Desktop and Google Cloud Readiness](desktop-readiness.md) for versions and completion commands.

## Established implementation decisions

1. Both applications use Go to keep the assessment focused on delivery and operations.
2. The primary and secondary regions are `us-central1` and `us-east1`.
3. Each application repository owns its application source, Dockerfile, Helm chart, and CI lifecycle.
4. The platform repository owns shared cloud infrastructure, cluster lifecycle, observability, and assessment documentation.

## Foundation deployment status

The foundation root was applied on October 7, 2026. The reviewed plan and apply both reported 12 additions, no changes, and no destructions. A post-apply refresh plan reported `No changes`, confirming that the deployed resources match the Terraform configuration. See [Foundation deployment evidence](evidence/foundation-deployment.md).

The primary-cluster backend is initialized at `terraform/assessment/primary-cluster`, but its state is empty because the cluster has not been applied. See [Primary cluster readiness](primary-cluster-readiness.md).

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
