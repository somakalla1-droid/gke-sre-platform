# GitHub Actions Keyless Image-Publishing Evidence

**Verified:** October 9, 2026 (America/Chicago)
**Project:** `gke-sre-assesment`
**Artifact Registry repository:** `us-central1/gke-apps`

## Identity foundation

Terraform created seven resources with no changes or destroys:

- Security Token Service API enablement.
- Workload Identity pool `github-actions`.
- GitHub OIDC provider `github`.
- Service account `github-artifact-publisher`.
- Repository-level `roles/artifactregistry.writer` for that service account.
- One `roles/iam.workloadIdentityUser` binding for each application repository.

A follow-up Terraform plan returned `No changes`. The provider reported
`ACTIVE` and used this condition:

```text
assertion.repository_owner_id == '261697749' &&
assertion.ref == 'refs/heads/main'
```

The service-account policy allowed only:

- `somakalla1-droid/gke-request-info-service`
- `somakalla1-droid/gke-response-service`

The GAR policy retained reader access for the two GKE node service accounts and
granted the GitHub publisher writer access only on `gke-apps`. No JSON
service-account key was created or stored in GitHub.

## Request-service publication

GitHub Actions run
[`37968287433`](https://github.com/somakalla1-droid/gke-request-info-service/actions/runs/37968287433)
completed both jobs successfully:

- `validate`: tests, vet, Helm lint/template verification, and local image build.
- `publish`: Google OIDC authentication, GAR login, and image push.

Artifact Registry verification:

| Field | Value |
| --- | --- |
| Commit/tag | `b8b000469fd9823338d88af91a491e6cc62b71d2` |
| Digest | `sha256:1d556c8e4e2ac825fe6990c4cbf280d95bf2c5993dfe8eb41ee243e3e3da9117` |
| Image | `us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-request-info-service` |

## Response-service publication

GitHub Actions run
[`37968980212`](https://github.com/somakalla1-droid/gke-response-service/actions/runs/37968980212)
completed both jobs successfully:

- `validate`: tests, vet, Helm lint, and local image build.
- `publish`: Google OIDC authentication, GAR login, and image push.

Artifact Registry verification:

| Field | Value |
| --- | --- |
| Commit/tag | `3b4a5da8bc23d760ae4ff90105e890bea1959be7` |
| Digest | `sha256:14e57c325f3d8a2036a86363b7324d58fa12deb248fc1ba5a5bbcbfa20ab7cfc` |
| Image | `us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-response-service` |

## CI/CD boundary

Pull requests receive read-only repository access and run validation without a
Google ID token. The publish job receives `id-token: write` only on a push to
`main`, and only after validation succeeds. Images use the full immutable Git
commit SHA as their tag.

Publishing does not change either GKE cluster. Updating a Helm release to a new
image tag remains a separately reviewed deployment action. This separation
prevents a successful build from automatically restaging production-like
workloads.

## Runner warnings

The verified runs reported non-blocking notices that several third-party action
versions target the older Node.js 20 action runtime and are temporarily forced
onto Node.js 24. They also announced a future `ubuntu-latest` migration. Both
runs completed successfully. Action major versions and the explicit runner
image should be reviewed before the announced migration date; these notices do
not invalidate the authentication or publication evidence.
