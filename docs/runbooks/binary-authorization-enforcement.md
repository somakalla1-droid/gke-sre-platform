# Binary Authorization Enforcement Runbook

## Purpose

Promote the project singleton Binary Authorization policy from audit-only to
blocking enforcement after both application digests have passed admission in
both clusters. This runbook separates review, apply, verification, negative
testing, and rollback.

The policy is project-wide. A foundation apply changes admission behavior for
both `gke-primary` and `gke-secondary` at the same time. Existing running Pods
are not restarted by the policy update, but every subsequent Pod create or
update is evaluated.

## Approved releases

| Application | Commit | GAR digest |
| --- | --- | --- |
| request-info | `790b3256a60e95c20b8d17317dca4214744b5b13` | `sha256:83b4a862364d00797d1207e7a01d5fadd5067f0474688c3247e9dab3a5e15382` |
| response | `08eb1da1ef88bbed3ea1a02e2fc56be677eab995` | `sha256:3a2343ed94bae7e610d912b293011f432ec68b42db1b08150a9e00dcfcfe6306` |

Do not proceed if either Deployment differs from these immutable references or
if either occurrence is absent. The complete audit evidence is in
[Binary Authorization Audit Evidence](../evidence/binary-authorization-audit.md).

## Pre-apply gate

Confirm the current policy is still audit-only:

```bash
terraform \
  -chdir=terraform/environments/assessment/foundation \
  output -raw binary_authorization_enforcement_mode
```

Expected:

```text
DRYRUN_AUDIT_LOG_ONLY
```

Confirm all application Pods are Ready in both contexts:

```bash
for context in \
  gke_gke-sre-assesment_us-central1-a_gke-primary \
  gke_gke-sre-assesment_us-east1-b_gke-secondary
do
  kubectl --context "$context" --namespace assessment-apps get deployments,pods
done
```

Confirm the exact Deployment image references and independently list their
attestations. The occurrence `publicKeyId` must equal the key ID registered on
`gke-release-attestor`.

Also confirm that recent admission events for all four Deployments have no
`imagepolicywebhook.image-policy.k8s.io/dry-run=true` denial label.

## Review the Terraform change

On the enforcement PR branch:

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/assessment/foundation validate
terraform \
  -chdir=terraform/environments/assessment/foundation \
  plan \
  -out=binauthz-enforcement.tfplan

terraform \
  -chdir=terraform/environments/assessment/foundation \
  show binauthz-enforcement.tfplan
```

The reviewed plan must contain:

```text
Plan: 0 to add, 1 to change, 0 to destroy.
```

The only managed resource changing must be
`module.foundation.google_binary_authorization_policy.assessment`. Its default
rule must retain `REQUIRE_ATTESTATION` and the same attestor while changing only
the enforcement behavior from `DRYRUN_AUDIT_LOG_ONLY` to
`ENFORCED_BLOCK_AND_AUDIT_LOG` (plus the policy description update).

Do not apply the PR-branch plan. Merge the reviewed PR, update local `main`, and
create a fresh saved plan from the merged commit.

## Apply from merged main

```bash
git switch main
git pull --ff-only

terraform -chdir=terraform/environments/assessment/foundation init -reconfigure
terraform -chdir=terraform/environments/assessment/foundation validate
terraform \
  -chdir=terraform/environments/assessment/foundation \
  plan \
  -out=binauthz-enforcement.tfplan

terraform \
  -chdir=terraform/environments/assessment/foundation \
  apply binauthz-enforcement.tfplan
```

Stop if the regenerated plan differs from the reviewed one.

## Positive verification

Confirm the live policy and Terraform output both report
`ENFORCED_BLOCK_AND_AUDIT_LOG`. Then restart one attested Deployment at a time,
waiting for each rollout before continuing:

```bash
for context in \
  gke_gke-sre-assesment_us-central1-a_gke-primary \
  gke_gke-sre-assesment_us-east1-b_gke-secondary
do
  kubectl --context "$context" --namespace assessment-apps \
    rollout restart deployment/response-gke-response-service
  kubectl --context "$context" --namespace assessment-apps \
    rollout status deployment/response-gke-response-service --timeout=5m

  kubectl --context "$context" --namespace assessment-apps \
    rollout restart deployment/request-info-gke-request-info-service
  kubectl --context "$context" --namespace assessment-apps \
    rollout status deployment/request-info-gke-request-info-service --timeout=5m
done
```

Verify both regional request-to-response paths after the rollouts.

## Negative control

Use the earlier request digest whose occurrence has a mismatched public-key ID.
It is harmless assessment code but does not satisfy the attestor:

```bash
kubectl \
  --context gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace assessment-apps \
  run binauthz-negative-check \
  --image=us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-request-info-service@sha256:657d53efca65daa73bf233bd2b1f425182bf732508714b3065d83298a87b55b8 \
  --restart=Never
```

Expected result: Kubernetes returns `Forbidden` and Binary Authorization names
the release attestor denial. If the Pod is unexpectedly created, delete it and
immediately execute the emergency rollback below. Do not generate repeated
denial requests because GKE Binary Authorization can fail open during service
or quota failures.

## Standard rollback

Revert the enforcement commit through an expedited reviewed PR so the
environment default returns to `DRYRUN_AUDIT_LOG_ONLY`. From merged rollback
`main`, create and inspect a fresh saved plan. It must update only the singleton
policy in place, from enforced back to audit-only, with no additions or
destructions. Apply that saved plan and verify the Terraform output.

## Emergency rollback

If enforcement is causing an active incident and the rollback PR cannot wait,
temporarily override the merged variable through Terraform:

```bash
terraform \
  -chdir=terraform/environments/assessment/foundation \
  plan \
  -var='binary_authorization_enforcement_mode=DRYRUN_AUDIT_LOG_ONLY' \
  -out=binauthz-emergency-audit.tfplan

terraform \
  -chdir=terraform/environments/assessment/foundation \
  apply binauthz-emergency-audit.tfplan
```

This intentionally creates a temporary difference from the merged default.
Open and merge the rollback PR immediately afterward so source and live state
again agree. Preserve the plan, apply output, incident record, and audit logs.

## Break-glass deployment

Break-glass is for an approved emergency where policy enforcement must remain
enabled but a specific Pod must bypass it. Add this label to the Pod template:

```yaml
metadata:
  labels:
    image-policy.k8s.io/break-glass: "true"
```

Every use is logged. Require incident approval, record a justification outside
the manifest, remove the label as soon as the emergency ends, and redeploy a
properly attested digest. Never commit the label to the normal Helm values or
templates.
