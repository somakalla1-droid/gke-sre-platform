# Binary Authorization Enforcement Evidence

**Verified:** October 11, 2026

**Project:** `gke-sre-assesment`

**Policy phase:** Blocking enforcement

## Result

The Terraform-managed project singleton Binary Authorization policy is set to
`ENFORCED_BLOCK_AND_AUDIT_LOG`. Both approved application digests were admitted
during controlled rolling updates in both GKE clusters. A known noncompliant
digest was then rejected by the admission webhook before Kubernetes created a
Pod.

This completes the enforcement gate that followed the documented audit-only
rollout.

## Applied policy

The reviewed post-merge Terraform plan contained:

```text
Plan: 0 to add, 1 to change, 0 to destroy.
```

Only
`module.foundation.google_binary_authorization_policy.assessment` changed in
place. The apply completed with `0 added, 1 changed, 0 destroyed`.

The live policy export confirmed:

```yaml
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: REQUIRE_ATTESTATION
  requireAttestationsBy:
  - projects/gke-sre-assesment/attestors/gke-release-attestor
```

## Approved immutable releases

| Application | Commit | GAR digest |
| --- | --- | --- |
| request-info | `790b3256a60e95c20b8d17317dca4214744b5b13` | `sha256:83b4a862364d00797d1207e7a01d5fadd5067f0474688c3247e9dab3a5e15382` |
| response | `08eb1da1ef88bbed3ea1a02e2fc56be677eab995` | `sha256:3a2343ed94bae7e610d912b293011f432ec68b42db1b08150a9e00dcfcfe6306` |

Before each restart, both clusters reported two Ready replicas for each
Deployment and the exact immutable references above.

## Positive admission tests

The response service was restarted and allowed to become Ready before the
dependent request-info service was restarted in each cluster:

1. `gke-primary` response: rollout succeeded.
2. `gke-primary` request-info: rollout succeeded.
3. `gke-secondary` response: rollout succeeded.
4. `gke-secondary` request-info: rollout succeeded.

Every rollout created replacement Pods while blocking enforcement was active,
proving that both release attestations satisfy the configured attestor.
The final health check showed all four Deployments at `2/2`, all eight
application Pods Ready, and zero container restarts.

### Primary end-to-end result

The primary external endpoint returned `HTTP/1.1 200 OK` for request ID
`binauthz-enforced-primary-001`. The payload identified:

- request-info in `gke-primary`, `us-central1`, at commit `790b3256...`;
- response in `gke-primary`, `us-central1`, at commit `08eb1da1...`; and
- successful request-ID propagation with response status 200.

### Secondary end-to-end result

The Kubernetes Service proxy returned a successful request-to-response payload
from `gke-secondary`, `us-east1`. It identified request-info commit
`790b3256...`, response commit `08eb1da1...`, and response status 200.

## Negative admission test

One controlled Pod-create request used this earlier request-info digest:

```text
sha256:657d53efca65daa73bf233bd2b1f425182bf732508714b3065d83298a87b55b8
```

Its attestation contains a public-key ID that does not match the key registered
on `gke-release-attestor`. The API server rejected the request with:

```text
Error from server (VIOLATES_POLICY): admission webhook
"imagepolicywebhook.image-policy.k8s.io" denied the request: ... denied by
Binary Authorization default admission rule. ... Invalid attestation: The
signature's public key ID didn't match the key of a known attestor
```

No diagnostic Pod was created. The negative test was intentionally executed
only once.

## Drift verification

The post-apply foundation refresh plan returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirms that the live enforced policy matches the merged Terraform
configuration.

## Operational disposition

- Keep the policy in `ENFORCED_BLOCK_AND_AUDIT_LOG`.
- Publish and attest an immutable digest before deploying any future release.
- Restart the dependency first, then its caller, during controlled validation.
- Use the reviewed rollback or approved break-glass procedure in the
  [enforcement runbook](../runbooks/binary-authorization-enforcement.md) if an
  incident prevents a normal attested release.
