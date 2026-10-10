# Terraform State Operations

## Backend

All assessment roots use the protected GCS bucket:

```text
gke-sre-assesment-tfstate-150538255871
```

State boundaries:

| Root | GCS prefix |
| --- | --- |
| Foundation | `terraform/assessment/foundation` |
| Primary cluster | `terraform/assessment/primary-cluster` |
| Secondary cluster | `terraform/assessment/secondary-cluster` |
| Multi-cluster fleet | `terraform/assessment/multi-cluster` |

This separates lifecycle and blast radius while retaining one secured storage boundary.

## Bucket controls

- Region: `us-central1`
- Uniform bucket-level access: enabled
- Public access prevention: enforced
- Object versioning: enabled
- Soft-delete protection: seven days

The bucket was bootstrapped once with `gcloud` because Terraform cannot use a backend bucket before that bucket exists.

## Initialize a root

After cloning or changing backend configuration:

```bash
terraform -chdir=terraform/environments/assessment/foundation init -reconfigure
```

Use the corresponding root directory for either cluster. Initialization configures backend access and downloads providers; it does not create the declared infrastructure.

## Operational rules

- Never commit `*.tfstate`, state backups, or saved plans.
- Never edit a state object manually.
- Do not run concurrent operations against the same prefix.
- Review every plan before applying it.
- Use `terraform state` commands only for deliberate recovery or refactoring.
- Application CI identities must not have access to this bucket.
- Avoid placing secrets directly in Terraform because values can appear in state.

## Verification

```bash
gcloud storage buckets describe gs://gke-sre-assesment-tfstate-150538255871
gcloud storage ls --recursive gs://gke-sre-assesment-tfstate-150538255871
```

GCS creates a state object only after Terraform first writes state. An initialized but unapplied root can therefore have no object yet.

The foundation root first wrote remote state on October 7, 2026. Its post-apply state contained 12 managed resources, and a refresh plan reported no drift. The foundation, primary-cluster, secondary-cluster, and multi-cluster state objects were all verified in the protected bucket on October 9, 2026.

## Cluster-state lifecycle

The primary-cluster backend was initialized successfully on October 7, 2026. `terraform state list` returned no resources, which is the expected pre-apply condition. Initialization configures access to the backend but does not create the cluster or manually upload a state snapshot.

Terraform wrote each root's state snapshot under its dedicated prefix during the first successful apply. State is written, locked, versioned, and read by Terraform; operators must not manually upload or edit it.

After each cluster apply, verify its state independently:

```bash
terraform -chdir=terraform/environments/assessment/primary-cluster state list
terraform -chdir=terraform/environments/assessment/primary-cluster plan -detailed-exitcode
```
