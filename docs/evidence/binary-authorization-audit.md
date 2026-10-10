# Binary Authorization Audit Evidence

**Verified:** October 10, 2026

**Project:** `gke-sre-assesment`

**Policy phase:** Audit only

## Result

Binary Authorization is enabled on both GKE clusters and evaluates the
Terraform-managed project singleton policy. Controlled request-service rolling
updates succeeded in both regions while Cloud Audit Logs recorded the expected
policy violations. This proves that policy evaluation is active and that
`DRYRUN_AUDIT_LOG_ONLY` does not interrupt existing workloads.

Blocking enforcement is not yet enabled.

## Deployed controls

- Artifact Analysis note: `gke-release-attestor-note`
- Binary Authorization attestor: `gke-release-attestor`
- Cloud KMS asymmetric signing key: `gke-release-attestor`, version 1
- Key algorithm: ECDSA P-256 with SHA-256
- Default evaluation mode: `REQUIRE_ATTESTATION`
- Default enforcement mode: `DRYRUN_AUDIT_LOG_ONLY`
- Google system-image policy evaluation: enabled
- Primary cluster evaluation: `PROJECT_SINGLETON_POLICY_ENFORCE`
- Secondary cluster evaluation: `PROJECT_SINGLETON_POLICY_ENFORCE`

The foundation post-apply refresh plan returned `No changes`, confirming that
the deployed policy, attestor, note, KMS resources, APIs, and IAM binding match
Terraform.

## Primary-cluster test

Before the controlled rollout:

- both request-service replicas were Ready;
- both response-service replicas were Ready; and
- the global endpoint returned HTTP 200 for request ID
  `binauthz-precheck`.

The request-service Deployment was restarted and completed its rolling update
successfully. Both new replicas became Ready and the endpoint returned HTTP 200
for request ID `binauthz-audit-rollout`.

Cloud Audit Logs recorded two `pods.create` events for `gke-primary` with:

```text
imagepolicywebhook.image-policy.k8s.io/dry-run: "true"
```

The overridden verification result named the configured release attestor and
allowed both Pods because the policy was in dry-run mode.

## Secondary-cluster test

Before the controlled rollout:

- both request-service replicas were Ready;
- both response-service replicas were Ready; and
- an in-cluster request returned the complete request-to-response service flow
  from `gke-secondary` for request ID `binauthz-secondary-precheck`.

The request-service Deployment was restarted and completed its rolling update
successfully. Both replacement replicas became Ready.

Cloud Audit Logs recorded two `pods.create` events for `gke-secondary` at
`2026-10-10T19:26:58Z` and `2026-10-10T19:27:09Z`. Both contained the dry-run
label and the configured attestor denial reason. The disposable precheck Pod
also produced the expected dry-run event.

## Audit finding: tags are not digests

Both clusters reported the same application-image finding:

```text
Expected digest with sha256 scheme, but got tag or malformed digest
```

The application currently uses this commit-derived tag:

```text
us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/
gke-request-info-service:03ea1316292d2c605b73b67d0eb28f31d775d0ee
```

A commit-derived tag improves traceability but is still a mutable tag. Binary
Authorization attestations are bound to an immutable image digest. Enforced
blocking must therefore remain disabled until both application charts deploy
their verified `repository@sha256:digest` references and those exact digests
have valid attestations.

## Evidence query

```bash
gcloud logging read \
  'resource.type="k8s_cluster" AND
   logName:"cloudaudit.googleapis.com%2Factivity" AND
   protoPayload.methodName="io.k8s.core.v1.pods.create" AND
   labels."imagepolicywebhook.image-policy.k8s.io/dry-run"="true"' \
  --project=gke-sre-assesment \
  --freshness=30m \
  --order=desc \
  --limit=20
```

Add `resource.labels.cluster_name="gke-primary"` or
`resource.labels.cluster_name="gke-secondary"` to isolate a region.

## Enforcement gate

Do not change the policy to `ENFORCED_BLOCK_AND_AUDIT_LOG` until all of the
following are complete:

1. Resolve and record both GAR image digests.
2. Update both Helm charts and releases to use immutable digest references.
3. Create a dedicated least-privilege signing identity.
4. Create and validate attestations for both digests with the KMS key.
5. Roll out both attested images to both clusters while still in audit mode.
6. Confirm that the audit logs no longer report attestor denial for those
   application images.
7. Review a separate Terraform enforcement plan and rollback procedure.
