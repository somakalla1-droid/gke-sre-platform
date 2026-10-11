# Assessment Cleanup Runbook

## Purpose and safety gate

Remove billable assessment resources after the reviewer confirms that all
required evidence has been retained. Cleanup is destructive and must use
reviewed, current `main` configuration and the correct project and contexts.

Do not run this procedure merely to test it. Before starting, obtain explicit
owner approval, preserve sanitized evidence, and confirm that no demonstration
or review session remains scheduled.

This runbook is prepared but has not been executed.

## 1. Pre-cleanup record

Capture without secrets:

- final Git commit of all three repositories;
- final application digests and attestations;
- Terraform state object generations;
- Terraform no-drift plan summaries;
- node, Deployment, Pod, Service, Gateway, and route status;
- the final global HTTP response;
- Grafana screenshot/export and BigQuery sample results; and
- current billing report and budget status.

Confirm the target explicitly:

```bash
gcloud config get-value project
gcloud projects describe gke-sre-assesment \
  --format='value(projectId,projectNumber,lifecycleState)'
kubectl config get-contexts
```

Stop if the project is not exactly `gke-sre-assesment`.

## 2. Revoke temporary external credentials

Revoke the temporary Google service-account key used by Grafana Cloud and the
unused Grafana Kubernetes-onboarding access-policy token. Delete the local key
file securely. Verify the GitHub application workflows use only OIDC and do not
contain stored Google service-account keys.

Revocation should occur even if the rest of cleanup is postponed.

## 3. Remove global routing first

Delete the resources that reference the multi-cluster backend before removing
Services, clusters, fleet features, or Cloud Armor:

```bash
kubectl \
  --context gke_gke-sre-assesment_us-central1-a_gke-primary \
  delete -k kubernetes/multi-cluster-gateway
```

Wait until the Gateway, route, forwarding rule, backend services, health
checks, and public address created for the Gateway are gone. Do not destroy the
Cloud Armor policy while a backend policy still references it.

## 4. Remove application releases

Uninstall the caller before its private dependency in both clusters:

```bash
for context in \
  gke_gke-sre-assesment_us-central1-a_gke-primary \
  gke_gke-sre-assesment_us-east1-b_gke-secondary
do
  helm --kube-context "$context" \
    --namespace assessment-apps uninstall request-info
  helm --kube-context "$context" \
    --namespace assessment-apps uninstall response
done
```

Verify that the primary single-cluster Ingress/load balancer, both
ServiceExports, application Services, and workload Pods have been removed.
Delete the namespace only after confirming it contains no unrelated resources.

## 5. Destroy Terraform roots in dependency order

Update local `main`, initialize every root, and create fresh destroy plans. Do
not reuse any old saved plan.

Destroy in this order:

1. `multi-cluster`;
2. `secondary-cluster`;
3. `primary-cluster`; and
4. `foundation`.

For each root:

```bash
terraform -chdir=terraform/environments/assessment/ROOT init -reconfigure
terraform \
  -chdir=terraform/environments/assessment/ROOT \
  plan -destroy -out=ROOT-destroy.tfplan
terraform \
  -chdir=terraform/environments/assessment/ROOT \
  show ROOT-destroy.tfplan
terraform \
  -chdir=terraform/environments/assessment/ROOT \
  apply ROOT-destroy.tfplan
```

Review the complete resource list and resolve unexpected additions, updates,
or unmanaged dependencies before applying a destroy plan.

## 6. Handle protected data before foundation destroy

The foundation intentionally protects evidence-bearing services:

- BigQuery dataset deletion is configured not to delete non-empty contents;
- Artifact Registry contains release and rollback images;
- Secret Manager contains a secret version; and
- KMS/attestation records preserve provenance history.

Decide and document retention requirements before deletion. Export required
sanitized evidence, then explicitly remove retained BigQuery tables and GAR
artifacts only with owner approval. Do not weaken protection flags silently to
make a destroy command pass. Cloud KMS keys have provider/service lifecycle
constraints and may remain as disabled or scheduled cryptographic metadata;
verify their final state rather than assuming immediate physical deletion.

## 7. Preserve and remove remote state last

The backend bucket is outside the Terraform roots. Keep it until every root has
been destroyed and verified. Preserve required state generations in an
approved secure archive. Only then remove the four state prefixes and the
bucket with explicit owner approval.

The bucket has versioning and seven-day soft delete, so deletion may remain
recoverable and billable during the retention window. Verify both live and
soft-deleted object behavior.

Remove ignored local `*.tfplan` files after they are no longer needed. Saved
plans can contain resolved infrastructure values and must not be committed or
placed in public evidence archives.

## 8. Final cost and residue verification

Confirm that no unexpected billable resources remain:

```bash
gcloud container clusters list --project=gke-sre-assesment
gcloud compute forwarding-rules list --project=gke-sre-assesment
gcloud compute backend-services list --project=gke-sre-assesment
gcloud compute addresses list --project=gke-sre-assesment
gcloud artifacts repositories list --project=gke-sre-assesment
gcloud secrets list --project=gke-sre-assesment
gcloud kms keyrings list --location=global --project=gke-sre-assesment
gcloud storage buckets list --project=gke-sre-assesment
```

Also review Billing reports and the project Asset Inventory because an empty
result from one product command does not prove the whole project is clean.

Cleanup is complete only when:

- both GKE clusters and all load-balancing resources are absent;
- temporary Grafana credentials and tokens are revoked;
- data-retention exceptions are documented;
- the state bucket is retained or removed intentionally;
- billing shows no unexpected continuing services; and
- [Requirements Traceability](../requirements-traceability.md) links the final
  cleanup evidence.
