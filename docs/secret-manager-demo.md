# Google Secret Manager Demo Design

**Status:** Terraform validated and planned; no secret version has been created or applied.

## Objective

Demonstrate secure application access to a sensitive value without committing it to Git, placing it in Terraform state, or creating a Kubernetes `Secret` copy.

## Design

```text
Local file outside Git
        |
        | bin/publish-demo-secret-version
        v
Google Secret Manager secret and version
        |
        | GKE Secret Manager CSI add-on + Workload Identity
        v
Read-only file mounted in the response-service Pod
```

Terraform owns only the secret container, the Secret Manager API, and the least-privilege IAM binding. It does not manage secret versions or values.

## Managed identity

The response service will run as this Kubernetes service-account principal:

```text
principal://iam.googleapis.com/projects/150538255871/locations/global/workloadIdentityPools/gke-sre-assesment.svc.id.goog/subject/ns/assessment-apps/sa/response-service-workload
```

It receives `roles/secretmanager.secretAccessor` on only `gke-sre-response-demo-token`. No node service account and no other workload receives this permission.

## Local file publication

After the Terraform foundation update has created the secret metadata, create a local file outside all Git repositories:

```bash
mkdir -p "$HOME/.config/gke-sre"
umask 077
openssl rand -base64 32 > "$HOME/.config/gke-sre/response-demo-token"
```

Publish it without displaying the value:

```bash
bin/publish-demo-secret-version \
  "$HOME/.config/gke-sre/response-demo-token"
```

The script uses `gcloud secrets versions add --data-file`, so the secret value is not placed in shell history or the process command line.

## Cluster integration

The shared GKE module enables the Secret Manager CSI add-on and automatic secret rotation every 120 seconds. The cluster update must be planned and reviewed separately from the foundation update.

Application charts will later add a `SecretProviderClass` and mount the secret through `secrets-store-gke.csi.k8s.io` as a read-only file. Verification will test that the expected file exists without printing its contents.

## Reviewed Terraform plan

Two independent Terraform state boundaries will be applied in this order after the platform pull request merges:

1. **Foundation:** `3 to add, 0 to change, 0 to destroy`.
   - Enable `secretmanager.googleapis.com`.
   - Create the empty `gke-sre-response-demo-token` secret container.
   - Grant exactly one Workload Identity principal access to that secret.
2. **Primary cluster:** `0 to add, 1 to change, 0 to destroy`.
   - Enable the Secret Manager CSI add-on in place.
   - Enable mounted-secret rotation every 120 seconds.

Terraform will not create a secret version or receive the secret payload. Do not run the local publication script until the foundation update has completed successfully.

## Future Helm deployment values

The response-service release will use a stable Kubernetes service-account name so it matches the IAM principal in the foundation configuration:

```bash
--namespace assessment-apps \
--set serviceAccount.name=response-service-workload
```

The future CSI configuration will mount the Secret Manager value as a file, rather than populating `secret.stringData` or creating a Kubernetes `Secret`.

## Deliberate exclusions

- No secret value is in Terraform, Helm values, GitHub Actions variables, or Git.
- No Secret Manager version is created automatically during Terraform apply.
- No Kubernetes `Secret` object is created for the GSM deployment path.
- The chart-managed Kubernetes Secret option remains a local-development fallback only.
