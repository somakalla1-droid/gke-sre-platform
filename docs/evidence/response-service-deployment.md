# Response-Service Deployment Evidence

**Verified:** October 8, 2026 (America/Chicago)  
**Cluster:** `gke-primary` in `us-central1-a`  
**Namespace:** `assessment-apps`  
**Helm release:** `response`  
**Source repository:** [gke-response-service](https://github.com/somakalla1-droid/gke-response-service)

## Release inputs

The response-service chart was deployed from its merged `main` branch using an immutable Artifact Registry image tag:

```text
us-central1-docker.pkg.dev/gke-sre-assesment/gke-apps/gke-response-service:02f767d7e54d
```

The deployment set `CLUSTER_NAME=gke-primary`, `REGION=us-central1`, and the fixed Kubernetes ServiceAccount name `response-service-workload`. The ServiceAccount is the identity granted read access only to the response demo secret through Workload Identity.

## Verified result

Helm reported:

```text
STATUS: deployed
DESCRIPTION: Install complete
```

The workload verification showed:

| Resource | Verified state |
| --- | --- |
| Deployment `response-gke-response-service` | `2/2` ready, up-to-date, and available |
| Response pods | Two `Running` pods, each `1/1` ready, zero restarts |
| Service | Internal `ClusterIP` service on port 80 |
| HPA | Two to five replicas; observed target `cpu: 0%/70%` |
| PodDisruptionBudget | `minAvailable: 1` |
| Helm rollout | Successfully rolled out |

The service intentionally remains internal at this stage. It is Application B and will be called by the request service before an external endpoint is added.

## Secret Manager verification without exposing a secret

The cluster has the GKE Secret Manager add-on enabled. The deployed chart created:

- ServiceAccount `response-service-workload`;
- `SecretProviderClass` `response-gke-response-service-gsm`;
- read-only CSI volumes in both response pods using driver `secrets-store-gke.csi.k8s.io`.

The provider configuration references the response demo secret at its `latest` version and mounts it as `response-demo-token`. Pod readiness proves the CSI volume mount succeeded. Neither the local source file, secret version payload, nor mounted file contents were printed, stored in Git, or copied into a Kubernetes Secret.

## Related troubleshooting evidence

The initial release exposed genuine capacity and security-context problems. Their diagnosis and Terraform/chart remediation are recorded in [response-service-capacity-incident.md](response-service-capacity-incident.md).
