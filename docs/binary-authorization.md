# Binary Authorization Audit-First Rollout

## Objective

Require release attestations for application images without risking an
unreviewed outage. The first phase evaluates a real `REQUIRE_ATTESTATION`
policy in `DRYRUN_AUDIT_LOG_ONLY`. Nonconforming deployments continue, but
Binary Authorization writes the decision to Cloud Audit Logs.

Enforced blocking is deliberately a separate change. It must not be enabled
until both approved image digests have valid attestations and the audit results
show that GKE system images and assessment workloads behave as expected.

## Terraform-managed resources

The foundation root adds:

- Binary Authorization, Artifact Analysis, and Cloud KMS APIs;
- global KMS key ring `gke-binary-authorization`;
- software-protected ECDSA P-256 signing key `gke-release-attestor`;
- Artifact Analysis attestation-authority note
  `gke-release-attestor-note`;
- Binary Authorization attestor `gke-release-attestor`;
- note-level occurrence-viewer access for the attestor's Google-managed
  delegation service account; and
- the project singleton policy.

The policy retains Google's system-image policy and evaluates every other image
against the release attestor:

```text
evaluation mode:  REQUIRE_ATTESTATION
enforcement mode: DRYRUN_AUDIT_LOG_ONLY
global policy:    ENABLE
```

Both cluster roots set the GKE evaluation mode to
`PROJECT_SINGLETON_POLICY_ENFORCE`. Despite that API name, whether a violation
blocks or only logs is controlled by the singleton policy's enforcement mode.
During this phase it only logs.

The policy uses the attestor's deterministic canonical resource name rather
than its computed Terraform ID. Google provider 7.46.1 can otherwise produce
an inconsistent final plan when the attestor and singleton policy are created
in the same apply. An explicit dependency still guarantees that the attestor
and its note access exist before Terraform creates the policy.

## Cost boundary

Binary Authorization for GKE is charged per enabled cluster. Google currently
provides a monthly credit approximately equal to one cluster; the second
assessment cluster can therefore add roughly USD 12 per month while enabled.
Cloud KMS key versions and signing operations can add small charges. Remove or
disable these controls during final cleanup if they are not being retained.

Review current pricing before every new environment:

- <https://cloud.google.com/binary-authorization/pricing>
- <https://cloud.google.com/kms/pricing>

## Review and apply order

Do not apply the cluster plans before the foundation policy and attestor exist.

```bash
terraform -chdir=terraform/environments/assessment/foundation init -reconfigure
terraform -chdir=terraform/environments/assessment/foundation validate
terraform -chdir=terraform/environments/assessment/foundation plan -out=binauthz-audit.tfplan
terraform -chdir=terraform/environments/assessment/foundation apply binauthz-audit.tfplan
```

Confirm the output is audit-only:

```bash
terraform \
  -chdir=terraform/environments/assessment/foundation \
  output binary_authorization_enforcement_mode
```

Expected value:

```text
DRYRUN_AUDIT_LOG_ONLY
```

Then plan and apply one cluster at a time, primary before secondary:

```bash
terraform -chdir=terraform/environments/assessment/primary-cluster plan -out=binauthz-audit.tfplan
terraform -chdir=terraform/environments/assessment/primary-cluster apply binauthz-audit.tfplan

terraform -chdir=terraform/environments/assessment/secondary-cluster plan -out=binauthz-audit.tfplan
terraform -chdir=terraform/environments/assessment/secondary-cluster apply binauthz-audit.tfplan
```

Each in-place cluster update can take several minutes. Existing application
Pods should remain available, but verify both clusters after each apply.

## Audit verification

Confirm cluster configuration without restarting workloads:

```bash
gcloud container clusters describe gke-primary \
  --zone=us-central1-a \
  --project=gke-sre-assesment \
  --format='value(binaryAuthorization.evaluationMode)'

gcloud container clusters describe gke-secondary \
  --zone=us-east1-b \
  --project=gke-sre-assesment \
  --format='value(binaryAuthorization.evaluationMode)'
```

Both commands must return `PROJECT_SINGLETON_POLICY_ENFORCE`.

Read the policy and attestor:

```bash
gcloud container binauthz policy export \
  --project=gke-sre-assesment

gcloud container binauthz attestors describe gke-release-attestor \
  --project=gke-sre-assesment
```

To produce a controlled audit decision, restart one application Deployment in
the primary cluster before its image is attested. The rollout must continue
because the policy is dry-run:

```bash
kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  rollout restart deployment/request-info-gke-request-info-service

kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  rollout status deployment/request-info-gke-request-info-service \
  --timeout=5m
```

Query recent Binary Authorization audit decisions:

```bash
gcloud logging read --order=desc \
  'resource.type="k8s_cluster" AND
   logName:"cloudaudit.googleapis.com%2Factivity" AND
   (protoPayload.methodName="io.k8s.core.v1.pods.create" OR
    protoPayload.methodName="io.k8s.core.v1.pods.update") AND
   labels."imagepolicywebhook.image-policy.k8s.io/dry-run"="true"' \
  --project=gke-sre-assesment \
  --freshness=30m \
  --limit=50 \
  --format=json
```

Retain sanitized evidence showing the violation was evaluated, logged, and not
blocked. Do not move to enforcement if no audit decision is visible.

The completed two-cluster test is recorded in
[Binary Authorization Audit Evidence](evidence/binary-authorization-audit.md).

## Next phase: attest before enforcing

After the audit phase succeeds:

1. Grant signing permissions to a dedicated release identity, not a human
   owner and not the GKE node service account.
2. Create and validate attestations for the exact request and response image
   digests.
3. Redeploy both attested images while the policy remains dry-run.
4. Confirm audit decisions recognize the valid attestations.
5. Change `enforcement_mode` to `ENFORCED_BLOCK_AND_AUDIT_LOG` through a
   separate reviewed PR and Terraform plan.
6. Prove an attested image succeeds and a harmless unsigned test image is
   rejected.

The approved image digests are recorded in
[Distributed Tracing Evidence](evidence/distributed-tracing.md). Tags alone are
not sufficient because Binary Authorization evaluates immutable digests.

## Rollback

If cluster integration causes unexpected behavior while the policy is dry-run,
set the affected cluster module variable back to `DISABLED`, review the plan,
and apply that cluster root. Do not delete the attestor, note, or KMS key while
investigating; retaining them preserves the audit trail.

If a future enforced policy blocks an emergency deployment, use the documented
Binary Authorization break-glass process with incident approval and retain its
audit log. Do not weaken the project policy silently.
