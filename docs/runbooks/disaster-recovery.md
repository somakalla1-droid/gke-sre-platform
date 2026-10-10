# Disaster Recovery and Backup Runbook

## Scope

This runbook covers recovery of the deployed assessment platform:

- two zonal GKE clusters in `us-central1-a` and `us-east1-b`;
- stateless request and response applications;
- the global multi-cluster Gateway and Cloud Armor policy;
- Terraform remote state;
- immutable Artifact Registry images;
- Secret Manager configuration; and
- reproducible logging, BigQuery, Grafana, and observability configuration.

The deployed applications do not use Cloud SQL, Memorystore, Firestore, or
PersistentVolumes. Therefore, the assessment has no customer application data
to restore. Its recovery model is regional failover followed by deterministic
recreation from Git, Terraform state, Helm charts, immutable images, and Secret
Manager. Production stateful-service recommendations are documented separately
below and must not be represented as deployed controls.

## Recovery objectives

These are assessment targets, not contractual production service levels:

| Recovery domain | Assessment RPO | Assessment RTO | Recovery source |
| --- | --- | --- | --- |
| Application traffic after one regional failure | Zero application-data loss because workloads are stateless | 5–15 minutes for health detection and global backend convergence | Healthy cluster behind the multi-cluster Gateway |
| Deleted application workload | Last merged chart and immutable image | 15 minutes | Application Git repository and GAR digest |
| Lost GKE cluster | Last merged Terraform and application releases | 60–120 minutes | Terraform, Helm charts, GAR, Secret Manager |
| Terraform state corruption/deletion | Last successful state generation | 30–60 minutes | Versioned GCS object and seven-day soft-delete window |
| Lost GAR image | Last reproducible Git commit | 30–60 minutes | Source repository and keyless CI rebuild |
| Production stateful data, if introduced | Proposed: no more than 5 minutes | Proposed: no more than 60 minutes | Database-native PITR, replicas, and tested restore procedures |

Actual recovery time depends on GKE and global load-balancer provisioning. The
controlled regional withdrawal test returned HTTP 200 from the secondary
region, but it was not a timed production SLO exercise.

## Current recovery inventory

### Terraform state

Bucket `gke-sre-assesment-tfstate-150538255871` is regional in `us-central1`
and currently has:

- uniform bucket-level access;
- public-access prevention enforced;
- object versioning enabled; and
- seven-day soft-delete retention.

The following live state objects were verified on October 9, 2026:

```text
terraform/assessment/foundation/default.tfstate
terraform/assessment/primary-cluster/default.tfstate
terraform/assessment/secondary-cluster/default.tfstate
terraform/assessment/multi-cluster/default.tfstate
```

The distinct prefixes limit the blast radius of a plan or recovery operation.
The regional bucket remains an assessment trade-off; production should use a
location and retention design aligned with the organization's regional-outage
requirements.

### Application releases

The recovery versions deployed in both clusters are:

| Application | Immutable tag | Digest |
| --- | --- | --- |
| Request info | `03ea1316292d2c605b73b67d0eb28f31d775d0ee` | `sha256:45d638bf0d373c90691e3733ab1e22ab7ebac1facefec8220766c990743ba457` |
| Response | `7aa78243c6cb864d7decfe80646ded3f0641c7fe` | `sha256:ab5fc6d7e62fd50dccc91f2b12008d9ac1d287d7def775883980dc0fe6f0abd6` |

The image repository is regional in `us-central1`. Git commit SHAs and the
keyless CI workflows provide a rebuild path if that repository is unavailable.
A rebuild must be compared with the expected software bill of materials and
test results; it must not be assumed to reproduce the same digest unless the
toolchain and dependencies are reproducible.

### Reproducible configuration

- Cloud infrastructure: this platform repository and four Terraform roots.
- Global routing: `kubernetes/multi-cluster-gateway`.
- Workloads: Helm chart in each application repository.
- Dashboard: `grafana/dashboards/gke-sre-assessment.json`.
- Log queries: `docs/observability-bigquery.md`.
- Secrets: Secret Manager versions; values are not stored in Git or Terraform.

## Incident entry checks

Do not make changes until the failure domain is identified. Capture the UTC
time, affected endpoint, request ID, current Git SHA, and current kubeconfig
context.

```bash
gcloud container fleet ingress describe \
  --project=gke-sre-assesment \
  --format='yaml(state,resourceState,membershipStates)'

kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  get deployments,pods,services,endpointslices,gateway,httproute

kubectl \
  --context=gke_gke-sre-assesment_us-east1-b_gke-secondary \
  --namespace=assessment-apps \
  get deployments,pods,services,endpointslices

curl -i \
  -H 'X-Request-ID: dr-triage-001' \
  http://136.81.84.189/
```

Classify the incident before following a procedure:

1. application Pod or rollout failure;
2. node or cluster failure;
3. regional backend failure;
4. global Gateway failure;
5. Terraform state loss or corruption;
6. image, secret, or stateful-data loss.

## Application recovery

### Pod failure

Kubernetes normally replaces a failed Pod. Confirm that the Deployment reaches
its declared replica count and that the Service has ready EndpointSlices:

```bash
kubectl \
  --context=<cluster-context> \
  --namespace=assessment-apps \
  rollout status deployment/<deployment-name> \
  --timeout=5m

kubectl \
  --context=<cluster-context> \
  --namespace=assessment-apps \
  get pods,endpointslices
```

If a bad application release caused the incident, inspect Helm history and
roll back only to a known-good revision. Do not use `kubectl edit` to create an
untracked fix.

```bash
helm \
  --kube-context <cluster-context> \
  --namespace assessment-apps \
  history <release>

helm \
  --kube-context <cluster-context> \
  --namespace assessment-apps \
  rollback <release> <known-good-revision> \
  --wait \
  --timeout 10m
```

Verify a request and its logs after rollback. Preserve the failed revision,
events, and root cause in an incident record.

## Regional failure and failback

The global Gateway uses health-checked Pod backends from both fleet members.
Loss of the primary backend should remove it from service without a DNS change.
During the incident:

1. Confirm the secondary Pods and Service endpoints are healthy.
2. Confirm Gateway and fleet membership state.
3. Send uniquely identified requests to the global endpoint.
4. Confirm responses report `gke-secondary` and `us-east1`.
5. Do not force traffic back while the primary backend is unstable.

The controlled procedure and its successful evidence are in
[Multi-Cluster Gateway Deployment and Recovery](multi-cluster-gateway.md) and
[Multi-Cluster Gateway evidence](../evidence/multi-cluster-gateway.md).

For failback, restore the primary workload and Service endpoints, wait for
Google Cloud backend health to become healthy, and then send a new request.
Failback is complete only when the primary response succeeds and both regional
backends remain healthy. Avoid changing DNS, Gateway, and application releases
simultaneously.

## Cluster recreation

Recreate dependencies in this order:

1. Foundation, only if shared networking, IAM, APIs, GAR, or observability
   resources are missing.
2. The failed cluster Terraform root.
3. Response service, because request-info depends on it.
4. Request-info service.
5. Fleet membership and multi-cluster features.
6. `ServiceExport`, Gateway, route, and backend policy.
7. Functional, logging, trace, and dashboard verification.

Use a saved plan produced from reviewed `main`; never reuse an old plan file
after state or configuration changes:

```bash
terraform -chdir=terraform/environments/assessment/<root> init -reconfigure
terraform -chdir=terraform/environments/assessment/<root> validate
terraform -chdir=terraform/environments/assessment/<root> plan -out=recovery.tfplan
terraform -chdir=terraform/environments/assessment/<root> apply recovery.tfplan
```

For application restoration, pin the immutable tags in the inventory above,
deploy response before request-info, and use explicit `--kube-context`. Verify
the rendered Secret Manager resource name before applying the response chart.

## Terraform state recovery

State recovery can orphan or duplicate infrastructure if performed against the
wrong object. It requires peer review and an incident change record.

1. Stop all Terraform applies for the affected root.
2. Confirm the backend prefix and list object generations.
3. Download the current and candidate previous generations to a protected
   temporary location.
4. Compare serial, lineage, resources, and a refresh-only plan.
5. Restore the selected generation only after review.
6. Run `terraform plan -refresh-only`, then a normal plan; do not apply until
   both results are understood.

Discovery commands are read-only:

```bash
gcloud storage ls --all-versions \
  gs://gke-sre-assesment-tfstate-150538255871/terraform/assessment/<root>/default.tfstate

terraform -chdir=terraform/environments/assessment/<root> state list
terraform -chdir=terraform/environments/assessment/<root> plan -refresh-only
```

Do not place downloaded state in Git, tickets, or chat. Terraform state can
contain sensitive values even when the current configuration avoids secrets.
Do not run `terraform state push`, import, or object-generation restoration as
an exploratory command.

## Artifact Registry recovery

Artifact Registry cleanup policies are retention controls, not backups. The
assessment repository is single-region and has no replicated backup
repository. Recovery order is:

1. Check whether the required digest still exists in `gke-apps`.
2. If it exists, deploy by the immutable tag or digest without rebuilding.
3. If it is unavailable, rebuild from the exact Git commit through the reviewed
   GitHub Actions workflow.
4. Run tests, vulnerability/provenance checks, and Helm validation.
5. Publish a new immutable tag and update the recovery inventory through PR.

Production should promote signed digests into a second regional repository and
periodically prove that both clusters can pull from the recovery repository.
Deletion-prevention and cleanup policy must preserve release and rollback
images for the agreed retention window.

## Kubernetes and stateful backup design

### GKE

GKE manages the control-plane `etcd`; operators do not take raw `etcd`
snapshots from a managed GKE control plane. The production equivalent is Backup
for GKE for selected Kubernetes resources and PersistentVolumes, with scheduled
backups, protected restore locations, retention, and routine restore tests.

Backup for GKE was not enabled in this assessment because both applications are
stateless, manifests and charts are version controlled, no PersistentVolumes
exist, and it would add cost without protecting application data. Cluster
recreation plus Helm deployment is the tested recovery pattern.

### Cloud SQL

Cloud SQL is not deployed. If persistent relational state is introduced,
production must enable regional HA, automated backups, point-in-time recovery,
and a cross-region recovery strategy. A restore test must create a separate
instance, validate application consistency, record the achieved RPO/RTO, and
avoid overwriting the source instance during testing.

### Memorystore and Firestore

Neither service is deployed. If used, select a tier and replication model that
meets the workload's RPO/RTO, document whether the data is authoritative or
rebuildable, and test export/restore or regional recovery using supported
service capabilities. A cache must not be treated as the sole system of record.

## Secret and observability recovery

- Restore Secret Manager access before starting dependent Pods. Rotate a
  compromised value by creating a new version; never recover it from logs or
  Terraform state.
- Reapply the Grafana dashboard JSON rather than editing the recovery dashboard
  manually.
- BigQuery application logs expire after 30 days and are evidence, not a backup
  of application data.
- Cloud Logging, Trace, Profiler, and Error Reporting are diagnostic systems;
  an outage in them must not block application readiness.

## Recovery exit criteria

Recovery is complete only when all applicable checks pass:

- Terraform state and live resources have no unexplained drift.
- Required nodes, Deployments, Pods, Services, HPAs, and PDBs are healthy.
- Both application versions match approved immutable tags.
- The global endpoint returns HTTP 200 with a unique request ID.
- Application A reaches Application B in the recovered region.
- Cloud Armor still blocks the controlled WAF test while normal traffic works.
- Structured logs and a distributed trace contain the recovery request ID.
- Dashboard panels receive current data.
- Temporary recovery resources and downloaded state files are removed securely.
- The incident record contains actual RPO, RTO, root cause, and follow-up work.

## Scheduled validation

Run quarterly in production and once before final assessment cleanup:

1. Review IAM and backup retention.
2. Verify remote-state object generations and a non-destructive plan.
3. Verify release digests in the primary and recovery registries.
4. Restore a workload into an isolated namespace or test cluster.
5. Perform a controlled regional backend withdrawal.
6. Restore stateful data into a separate target, when applicable.
7. Record measured RPO/RTO and remediate deviations.
