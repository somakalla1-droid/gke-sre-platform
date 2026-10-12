# End-to-End Setup Guide

## Purpose

Reproduce the verified assessment in dependency order. This guide is the
reviewer entry point; component-specific rationale and recovery details remain
in the linked documents.

The commands target project `gke-sre-assesment`. They create billable GKE,
load-balancing, logging, and security resources. Set a budget alert first and
follow the [cleanup runbook](runbooks/cleanup.md) after evidence review.

## 1. Prerequisites

Required local tools:

- Google Cloud CLI and GKE auth plugin;
- Terraform `>= 1.10, < 2.0`;
- `kubectl` and Helm;
- Docker;
- Git and GitHub CLI; and
- Go for application tests.

Verify the workstation with
[Desktop and Google Cloud Readiness](desktop-readiness.md). The project must
exist with billing enabled. The operator needs sufficient project, IAM,
service-usage, Kubernetes, and billing visibility for the reviewed assessment
changes.

Clone the three repositories:

```bash
cd /Users/somakalla/Documents/ChatGPT
git clone https://github.com/somakalla1-droid/gke-sre-platform.git GKE-SRE
git clone https://github.com/somakalla1-droid/gke-request-info-service.git
git clone https://github.com/somakalla1-droid/gke-response-service.git
```

Authenticate the CLI and Terraform Application Default Credentials:

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project gke-sre-assesment
gcloud config set project gke-sre-assesment
```

Confirm that the active CLI and ADC identities are intentional before
continuing. Do not store tokens, downloaded keys, kubeconfig files, or secret
values in any repository.

## 2. Bootstrap protected Terraform state

The GCS backend bucket is a prerequisite and is not managed by a root that
uses it. The assessment bucket is:

```text
gke-sre-assesment-tfstate-150538255871
```

It must have uniform bucket-level access, public-access prevention, object
versioning, and seven-day soft delete. Its four state prefixes are documented
in [Terraform State Operations](terraform-state.md). If the bucket already
exists, verify it rather than recreating it:

```bash
gcloud storage buckets describe \
  gs://gke-sre-assesment-tfstate-150538255871
```

## 3. Apply the shared foundation

All applies follow the same gate: review a PR, merge, update local `main`,
create a fresh saved plan, inspect it, and apply that exact plan.

```bash
cd /Users/somakalla/Documents/ChatGPT/GKE-SRE
git switch main
git pull --ff-only

terraform -chdir=terraform/environments/assessment/foundation init -reconfigure
terraform -chdir=terraform/environments/assessment/foundation validate
terraform \
  -chdir=terraform/environments/assessment/foundation \
  plan -out=foundation.tfplan
terraform \
  -chdir=terraform/environments/assessment/foundation \
  show foundation.tfplan
terraform \
  -chdir=terraform/environments/assessment/foundation \
  apply foundation.tfplan
```

The foundation creates the VPC/subnets, required APIs, Artifact Registry,
Cloud Armor, BigQuery export, observability IAM, Secret Manager metadata,
GitHub federation identities, KMS-backed release attestor, and enforced Binary
Authorization policy.

Add the demonstration secret value from a local file without printing it:

```bash
./bin/publish-demo-secret-version /absolute/path/to/local-secret-file
```

Delete the local source file securely when it is no longer required.

## 4. Publish and attest application images

Each application `main` workflow must succeed after the foundation identities
exist. It tests the application and chart, publishes a commit-SHA image,
resolves its GAR digest, exchanges a separate GitHub OIDC credential for the
release signer, and creates a KMS-backed Binary Authorization attestation.

Verified releases:

| Application | Version | Digest |
| --- | --- | --- |
| request-info | `790b3256a60e95c20b8d17317dca4214744b5b13` | `sha256:83b4a862364d00797d1207e7a01d5fadd5067f0474688c3247e9dab3a5e15382` |
| response | `08eb1da1ef88bbed3ea1a02e2fc56be677eab995` | `sha256:3a2343ed94bae7e610d912b293011f432ec68b42db1b08150a9e00dcfcfe6306` |

Confirm both exact `repository@sha256:...` occurrences with `gcloud container
binauthz attestations list` before deploying. Tags alone are insufficient.

## 5. Create both GKE clusters

Apply the primary and secondary roots independently:

```bash
for root in primary-cluster secondary-cluster
do
  terraform -chdir="terraform/environments/assessment/${root}" init -reconfigure
  terraform -chdir="terraform/environments/assessment/${root}" validate
  terraform \
    -chdir="terraform/environments/assessment/${root}" \
    plan -out="${root}.tfplan"
  terraform \
    -chdir="terraform/environments/assessment/${root}" \
    show "${root}.tfplan"
done
```

Inspect both plans and stop on any unexpected replacement or destruction.
After approval, apply each reviewed plan separately:

```bash
terraform \
  -chdir=terraform/environments/assessment/primary-cluster \
  apply primary-cluster.tfplan
terraform \
  -chdir=terraform/environments/assessment/secondary-cluster \
  apply secondary-cluster.tfplan
```

Fetch explicit kubeconfig contexts and verify three Ready nodes per cluster:

```bash
gcloud container clusters get-credentials gke-primary \
  --zone us-central1-a --project gke-sre-assesment
gcloud container clusters get-credentials gke-secondary \
  --zone us-east1-b --project gke-sre-assesment

kubectl --context gke_gke-sre-assesment_us-central1-a_gke-primary get nodes
kubectl --context gke_gke-sre-assesment_us-east1-b_gke-secondary get nodes
```

## 6. Enable the fleet and multi-cluster controllers

```bash
terraform -chdir=terraform/environments/assessment/multi-cluster init -reconfigure
terraform -chdir=terraform/environments/assessment/multi-cluster validate
terraform \
  -chdir=terraform/environments/assessment/multi-cluster \
  plan -out=multi-cluster.tfplan
terraform \
  -chdir=terraform/environments/assessment/multi-cluster \
  show multi-cluster.tfplan
terraform \
  -chdir=terraform/environments/assessment/multi-cluster \
  apply multi-cluster.tfplan

gcloud container fleet ingress describe \
  --project=gke-sre-assesment \
  --format='yaml(state,resourceState,membershipStates)'
```

Do not deploy routing resources until the feature is Ready and both membership
states are `OK`.

## 7. Deploy the response service first

Run the response release once per cluster, changing only context, cluster name,
and region:

```bash
cd /Users/somakalla/Documents/ChatGPT/gke-response-service

helm --kube-context CLUSTER_CONTEXT \
  upgrade --install response charts/gke-response-service \
  --namespace assessment-apps \
  --create-namespace \
  --set image.repository=us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-response-service \
  --set-string image.tag=08eb1da1ef88bbed3ea1a02e2fc56be677eab995 \
  --set-string image.digest=sha256:3a2343ed94bae7e610d912b293011f432ec68b42db1b08150a9e00dcfcfe6306 \
  --set serviceAccount.name=response-service-workload \
  --set config.clusterName=CLUSTER_NAME \
  --set config.region=REGION \
  --set observability.enabled=true \
  --set observability.projectId=gke-sre-assesment \
  --set secretManager.enabled=true \
  --set-string secretManager.projectNumber=150538255871 \
  --wait \
  --timeout 10m \
  --rollback-on-failure
```

Use these substitutions:

| Cluster | `CLUSTER_CONTEXT` | `CLUSTER_NAME` | `REGION` |
| --- | --- | --- | --- |
| Primary | `gke_gke-sre-assesment_us-central1-a_gke-primary` | `gke-primary` | `us-central1` |
| Secondary | `gke_gke-sre-assesment_us-east1-b_gke-secondary` | `gke-secondary` | `us-east1` |

Wait for each response rollout before deploying its caller.

## 8. Deploy request-info and export it through MCS

```bash
cd /Users/somakalla/Documents/ChatGPT/gke-request-info-service

helm --kube-context CLUSTER_CONTEXT \
  upgrade --install request-info charts/gke-request-info-service \
  --namespace assessment-apps \
  --create-namespace \
  --set image.repository=us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-request-info-service \
  --set-string image.tag=790b3256a60e95c20b8d17317dca4214744b5b13 \
  --set-string image.digest=sha256:83b4a862364d00797d1207e7a01d5fadd5067f0474688c3247e9dab3a5e15382 \
  --set config.clusterName=CLUSTER_NAME \
  --set config.region=REGION \
  --set config.responseServiceURL=http://response-gke-response-service.assessment-apps.svc.cluster.local \
  --set observability.enabled=true \
  --set observability.projectId=gke-sre-assesment \
  --set serviceExport.enabled=true \
  --wait \
  --timeout 10m \
  --rollback-on-failure
```

Use the same cluster substitutions as the response service. Enable the optional
single-cluster Ingress only in primary if the documented rollback endpoint is
required. If Helm 4 reports the known GKE-managed NEG annotation ownership
conflict on that existing primary Service, inspect it and use
`--force-conflicts` only for that reviewed field-manager conflict.

## 9. Create the global Gateway

Wait for both `ServiceExport` resources to report `Exported=True` and for
`ServiceImport/request-info-gke-request-info-service` to exist. Then apply the
Cloud Armor backend policy, Gateway, and route from the primary config cluster:

```bash
cd /Users/somakalla/Documents/ChatGPT/GKE-SRE
kubectl \
  --context gke_gke-sre-assesment_us-central1-a_gke-primary \
  apply -k kubernetes/multi-cluster-gateway

kubectl \
  --context gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace assessment-apps \
  get gateway/request-info-global httproute/request-info-global
```

Provisioning is asynchronous. Continue only after the Gateway is programmed,
the route is accepted, the backend policy is attached, and backend health is
green. See the [Multi-Cluster Gateway runbook](runbooks/multi-cluster-gateway.md).

Complete the public DNS and trusted TLS cutover by following the
[HTTPS and DuckDNS cutover runbook](runbooks/https-duckdns.md). Acceptance
requires the DuckDNS record and Gateway to use the Terraform-owned global IP,
the Google-managed certificate and domain status to report `ACTIVE`, a normal
HTTPS request to return HTTP 200, and the safe Cloud Armor SQLi regression to
return HTTP 403.

## 10. Configure and verify observability

Use the least-privilege `grafana-observability` identity to configure the
BigQuery and Google Cloud Monitoring data sources, then import
`grafana/dashboards/gke-sre-assessment.json`. Follow:

- [BigQuery application-log export](observability-bigquery.md);
- [Grafana Cloud setup](grafana-cloud.md);
- [Grafana dashboard](grafana-dashboard.md); and
- [Application observability](application-observability.md).

Treat any temporary Grafana credential as short-lived evidence infrastructure
and revoke it during cleanup.

## 11. Acceptance checks

The deployment is accepted only when:

1. all four Terraform refresh plans report no changes;
2. both fleet memberships are `OK`;
3. all six nodes and all eight application Pods are Ready;
4. the trusted HTTPS global endpoint returns HTTP 200 and both application
   versions;
5. controlled failover returns a secondary-region response;
6. Cloud Armor blocks the safe WAF test;
7. logs, BigQuery queries, dashboard panels, trace, profiler, and Error
   Reporting evidence are present; and
8. Binary Authorization admits both approved digests and rejects the documented
   mismatched attestation.

The verified results are summarized in
[Final Assessment Audit](evidence/final-audit.md).
