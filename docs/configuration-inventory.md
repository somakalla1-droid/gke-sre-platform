# Configuration Inventory

**Collected:** October 11, 2026
**Purpose:** Record the deployed configuration and outstanding production decisions for the GKE SRE assessment without committing credentials or sensitive billing data.

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
| Default zone | `us-central1-a` | Verified deployment |
| Secondary region | `us-east1` | Verified deployment |
| Secondary zone | `us-east1-b` | Verified deployment |

The authenticated GCP account and billing account identifier are intentionally not stored in this repository. They can be verified locally with:

```bash
gcloud auth list
gcloud billing projects describe gke-sre-assesment
```

### Representative verified enabled APIs

- `artifactregistry.googleapis.com`
- `bigquery.googleapis.com`
- `binaryauthorization.googleapis.com`
- `billingbudgets.googleapis.com`
- `cloudkms.googleapis.com`
- `cloudprofiler.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `cloudtrace.googleapis.com`
- `connectgateway.googleapis.com`
- `containeranalysis.googleapis.com`
- `compute.googleapis.com`
- `container.googleapis.com`
- `gkehub.googleapis.com`
- `iam.googleapis.com`
- `iamcredentials.googleapis.com`
- `logging.googleapis.com`
- `monitoring.googleapis.com`
- `multiclusteringress.googleapis.com`
- `multiclusterservicediscovery.googleapis.com`
- `secretmanager.googleapis.com`
- `serviceusage.googleapis.com`
- `sts.googleapis.com`

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
| Primary cluster | `gke-primary`, `us-central1-a`, three `e2-medium` nodes | Verified deployment |
| Secondary cluster | `gke-secondary`, `us-east1-b`, three `e2-medium` nodes | Verified deployment |
| Artifact Registry repository | `gke-apps`, Docker, `us-central1` | Verified |
| Terraform state bucket | `gke-sre-assesment-tfstate-150538255871` | Verified |
| BigQuery dataset | `assessment_app_logs`, US, 30-day table retention | Verified deployment |
| Log sink | `assessment-app-request-logs-to-bigquery` | Verified deployment |
| Fleet | Default fleet with both cluster memberships healthy | Verified deployment |
| Global Gateway | `request-info-global`, `8.232.146.143`, HTTPS 443 and HTTP 80 | Verified deployment |
| Public DNS and TLS | `gke-sre-assessment.duckdns.org`; Google-managed certificate `gke-sre-assessment-gateway-cert`, `ACTIVE` | Verified deployment |
| Cloud Armor | `gke-assessment-web-waf`, SQLi/XSS deny rules | Verified deployment |
| Binary Authorization | `REQUIRE_ATTESTATION`, `ENFORCED_BLOCK_AND_AUDIT_LOG` | Verified deployment |
| Secret Manager | `gke-sre-response-demo-token` with workload-scoped access | Verified deployment |

The state bucket uses uniform bucket-level access, enforced public-access prevention, object versioning, and GCP soft-delete protection. Each Terraform root uses a distinct object prefix.

Both clusters use the regular release channel, VPC-native alias ranges,
Shielded Nodes with Secure Boot, GKE Workload Identity, the Secret Manager
add-on, and the Gateway API standard channel. Application resource requests,
limits, probes, disruption budgets, and HPA bounds are owned by the Helm charts.

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

| Component | Deployed configuration | Status |
| --- | --- | --- |
| Workload Identity Pool | `github-actions` | Verified deployment |
| Identity Provider | GitHub OIDC, owner ID and `refs/heads/main` restricted | Verified deployment |
| Platform deployer identity | Local authenticated operator after PR and saved-plan review | Intentional manual control |
| Application publisher | `github-artifact-publisher`, repository-scoped GAR writer | Verified deployment |
| Release signer | `github-release-attestor`, KMS/attestation permissions without GAR write | Verified deployment |
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

## Deployment status

All four Terraform roots have protected remote state and deployed resources:

- `foundation` — VPC, subnets, APIs, GAR, IAM, observability, Cloud Armor,
  Secret Manager, GitHub federation, KMS, attestations, and Binary Authorization;
- `primary-cluster` — `gke-primary` and its three-node pool;
- `secondary-cluster` — `gke-secondary` and its three-node pool; and
- `multi-cluster` — fleet memberships and multi-cluster service/Gateway
  features.

On October 11, 2026, refresh plans for all four roots returned `No changes`.
See the deployment evidence and [Final Assessment Audit](evidence/final-audit.md).

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
