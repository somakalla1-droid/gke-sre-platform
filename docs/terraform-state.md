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
