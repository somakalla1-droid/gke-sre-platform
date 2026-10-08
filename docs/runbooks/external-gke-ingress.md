# External GKE Ingress Runbook

## Purpose

Expose the request service through a short-lived, public GKE external Application Load Balancer while keeping the response service private. Use this runbook for a demonstration endpoint, incident recovery, or controlled endpoint recreation.

The deployment path is:

```text
Internet → GKE external Application Load Balancer → request service → response service
```

This runbook is based on the `gke-sre-assesment` environment, but its checks and recovery sequence are reusable.

## Ownership and source of truth

| Concern | Source of truth | Do not do |
| --- | --- | --- |
| GKE HTTP load-balancing add-on | Platform Terraform | Enable or disable it manually in the console. |
| Ingress, Service, and NEG annotation | Request-service Helm chart | Manually edit a Helm-owned Kubernetes resource. |
| Application image and release values | Request-service repository and Helm release | Use a mutable `latest` image to demonstrate a release. |

## Cost and security guardrails

- An external Application Load Balancer is billable. Create it only for the demonstration window and remove it after evidence is captured.
- The response service must remain `ClusterIP`; only the request service receives an Ingress.
- This runbook exposes HTTP by public IP. HTTPS requires a domain, DNS record, and certificate strategy; do not claim HTTPS evidence until those are configured.
- Use a commit-SHA image tag. Never include a secret in an Ingress manifest, Helm value, command line, or test output.

## Prerequisites

Set the environment values for the assessment environment:

```bash
export PROJECT_ID=gke-sre-assesment
export CLUSTER_NAME=gke-primary
export CLUSTER_ZONE=us-central1-a
export NAMESPACE=assessment-apps
export RELEASE=request-info
export INGRESS_NAME=request-info-gke-request-info-service
```

Confirm the cluster and applications are healthy:

```bash
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$CLUSTER_ZONE" \
  --project "$PROJECT_ID"

kubectl -n "$NAMESPACE" get deployment,pods,service
helm status "$RELEASE" -n "$NAMESPACE"
```

The request and response deployments should both be ready before the public endpoint is enabled.

## Standard deployment procedure

### 1. Confirm the platform add-on is enabled

The GKE controller does not reconcile external Ingress resources unless the HTTP load-balancing add-on is enabled.

```bash
gcloud container clusters describe "$CLUSTER_NAME" \
  --zone "$CLUSTER_ZONE" \
  --project "$PROJECT_ID" \
  --format='json(addonsConfig.httpLoadBalancing)'
```

Expected: an `httpLoadBalancing` object is present. If it is absent, follow [Address remains empty: add-on disabled](#address-remains-empty-add-on-disabled); do not enable it manually.

### 2. Update the merged Helm release

From the merged request-service repository checkout:

```bash
git switch main
git pull --ff-only

helm upgrade "$RELEASE" charts/gke-request-info-service \
  --namespace "$NAMESPACE" \
  --reuse-values \
  --set ingress.enabled=true \
  --wait \
  --timeout 15m \
  --rollback-on-failure
```

`--reuse-values` preserves the tested image tag, cluster/region values, and the internal response-service URL. The chart enables the NEG annotation only when Ingress is enabled.

### 3. Wait for the public address and healthy backend

Provisioning takes several minutes. Check both the Kubernetes object and controller events:

```bash
kubectl -n "$NAMESPACE" get ingress "$INGRESS_NAME" -w
```

When `ADDRESS` is present, stop the watch with `Ctrl+C`, then run:

```bash
kubectl -n "$NAMESPACE" describe ingress "$INGRESS_NAME"
```

Expected evidence:

- a public IPv4 address;
- `kubernetes.io/ingress.class: gce` annotation;
- a backend status of `HEALTHY`;
- `Sync` and `IPChanged` events from `loadbalancer-controller`.

### 4. Verify the public request path

Use a fixed request ID that is safe to record in logs:

```bash
export PUBLIC_IP="REPLACE_WITH_INGRESS_ADDRESS"

curl -i "http://${PUBLIC_IP}/" \
  -H "X-Request-ID: public-endpoint-001"
```

Expected: HTTP `200`, request-service metadata, nested response-service metadata, and the same request ID in both payloads.

Verify structured log correlation without reading any secret:

```bash
kubectl -n "$NAMESPACE" logs \
  -l app.kubernetes.io/name=gke-request-info-service \
  --prefix --tail=100 | rg 'public-endpoint-001'

kubectl -n "$NAMESPACE" logs \
  -l app.kubernetes.io/name=gke-response-service \
  --prefix --tail=100 | rg 'public-endpoint-001'
```

## Troubleshooting

### Address remains empty: add-on disabled

Symptoms:

- `kubectl get ingress` shows a blank `ADDRESS` for more than 10 minutes;
- there are no GKE-managed forwarding rules;
- cluster `addonsConfig` does not contain `httpLoadBalancing`.

Diagnosis:

```bash
gcloud container clusters describe "$CLUSTER_NAME" \
  --zone "$CLUSTER_ZONE" \
  --project "$PROJECT_ID" \
  --format='json(addonsConfig)'
```

Remediation: add this to the platform cluster Terraform module, submit a PR, merge it, generate a fresh plan, and apply that reviewed plan:

```hcl
addons_config {
  http_load_balancing {
    disabled = false
  }
}
```

After the add-on update completes, wait for the controller to reconcile the existing Ingress. No new Ingress is required.

### Address remains empty: wrong Ingress class selector

Symptoms:

- the add-on is enabled;
- the Ingress is present but remains unprocessed;
- no forwarding rule or controller events appear.

GKE's built-in controller requires this annotation:

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: "gce"
```

Do **not** use `spec.ingressClassName: gce` to select the GKE controller. Kubernetes emits a generic deprecation warning for the annotation, but GKE documents the annotation as the required selector. Correct the Helm chart, merge the change, and upgrade the release.

### Backend is not healthy

Inspect the Service, pods, endpoints, readiness, and Ingress events:

```bash
kubectl -n "$NAMESPACE" get service,endpoints,pods
kubectl -n "$NAMESPACE" describe ingress "$INGRESS_NAME"
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp
```

Check that:

- the Service selects the ready request-service pods;
- port 80 targets the named container port `http` (8080);
- the request-service readiness endpoint returns successfully;
- the Service has `cloud.google.com/neg: '{"ingress": true}'` while Ingress is enabled.

Fix the Helm chart or application through a PR. Do not patch the live Service or Ingress manually.

### Public IP exists, but the first request fails

After `IPChanged`, the global frontend can need a short propagation period. First inspect the backend status:

```bash
kubectl -n "$NAMESPACE" describe ingress "$INGRESS_NAME"
```

If it reports `HEALTHY`, wait a few minutes and retry the same `curl` command. If it remains unhealthy, use the backend-health steps above.

For deeper, read-only GCP diagnostics:

```bash
gcloud compute forwarding-rules list --global --project "$PROJECT_ID"
gcloud compute url-maps list --global --project "$PROJECT_ID"
gcloud compute backend-services list --global --project "$PROJECT_ID"
```

## Evidence checklist

Capture these for the assessment before cleanup:

- `kubectl get ingress` showing the public address;
- successful HTTP response with nested response-service metadata;
- matching request ID in request-service and response-service logs;
- Ingress backend reported as healthy;
- the immutable image tag and Helm revision;
- the troubleshooting record if a remediation was required.

## Cleanup

Remove the external endpoint after the demo to stop future load-balancer charges. This does not remove either application deployment or its internal service:

```bash
helm upgrade "$RELEASE" charts/gke-request-info-service \
  --namespace "$NAMESPACE" \
  --reuse-values \
  --set ingress.enabled=false \
  --wait \
  --timeout 15m
```

Verify the Ingress is gone and that GKE-managed forwarding rules have been removed. Deletion can also take several minutes:

```bash
kubectl -n "$NAMESPACE" get ingress
gcloud compute forwarding-rules list --global --project "$PROJECT_ID"
```

Record the cleanup time and outcome in the assessment evidence.

## References

- [Configure Ingress for external Application Load Balancers](https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress)
- [Troubleshoot GKE Ingress](https://cloud.google.com/kubernetes-engine/docs/troubleshooting/ingress)
- [Cloud Load Balancing pricing](https://cloud.google.com/load-balancing/pricing)
