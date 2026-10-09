# GitHub Actions Keyless Image Publishing

## Purpose

The application repositories already run unit tests, Go vet, Helm linting, and
a local Docker build. The next CI/CD stage publishes commit-addressed images to
Artifact Registry after a successful push to `main`, without storing a Google
service-account key in GitHub.

## Trust flow

1. A workflow on the `main` branch requests a short-lived GitHub OIDC token.
2. Google Security Token Service validates that token through the
   `github-actions/github` Workload Identity provider.
3. The provider accepts only tokens whose immutable GitHub owner ID is
   `261697749` and whose ref is `refs/heads/main`.
4. The service-account IAM policy separately permits only these repositories:
   - `somakalla1-droid/gke-request-info-service`
   - `somakalla1-droid/gke-response-service`
5. The workflow impersonates
   `github-artifact-publisher@gke-sre-assesment.iam.gserviceaccount.com`.
6. That service account has `roles/artifactregistry.writer` only on the
   `gke-apps` repository, not at project scope.
7. Docker pushes an image tagged with the immutable Git commit SHA.

This design does not create or store a JSON service-account key. Pull-request
validation does not receive `id-token: write` and does not publish an image.

## Terraform resources

The foundation root manages:

- Security Token Service API enablement.
- Workload Identity pool `github-actions`.
- OIDC provider `github` with the GitHub token issuer.
- Dedicated service account `github-artifact-publisher`.
- Repository-level Artifact Registry writer access.
- One `roles/iam.workloadIdentityUser` binding per application repository.

The provider and service-account email are exposed as Terraform outputs for
the application workflows:

```text
projects/150538255871/locations/global/workloadIdentityPools/github-actions/providers/github
github-artifact-publisher@gke-sre-assesment.iam.gserviceaccount.com
```

## Ordered rollout

The infrastructure and workflow changes are intentionally separated:

1. Merge the platform Terraform change.
2. Apply the reviewed foundation plan and verify a drift-free follow-up plan.
3. Update each application workflow to authenticate with
   `google-github-actions/auth`, log in with the returned access token, and push
   its commit-SHA image.
4. Merge one application workflow at a time and verify the published digest in
   Artifact Registry.
5. Record the workflow run URLs, image tags, and digests as delivery evidence.

This ordering prevents application pipelines from referencing an identity
provider or service account that does not yet exist.

## Implemented workflow boundary

The publish job runs only after validation succeeds on a push to `main`:

```yaml
permissions:
  contents: read
  id-token: write
```

It uses `google-github-actions/auth` with `token_format: access_token`, then
passes that short-lived token to Docker for `us-central1-docker.pkg.dev`. The
image tag is `${{ github.sha }}`. Deployment remains a separately reviewed CD
step; publishing an image does not automatically change either GKE cluster.

The completed workflow runs, immutable tags, and GAR digests are recorded in
[GitHub Actions keyless image-publishing evidence](evidence/github-actions-image-publishing.md).

## Rollback and cleanup

Disabling the provider immediately prevents new GitHub token exchanges. The
publisher service account can also be disabled independently. During final
assessment cleanup, Terraform removes the repository IAM grant, service-account
impersonation bindings, provider, pool, and service account. Existing images
remain in Artifact Registry until the repository or individual versions are
explicitly removed.
