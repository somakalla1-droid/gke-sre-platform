# Multi-Cluster Gateway Deployment and Recovery

## Scope

This runbook deploys the assessment's global external HTTP entry point from the
primary config cluster. The Gateway sends traffic directly to healthy
`gke-request-info-service` Pods exported from both GKE clusters. Request-service
Pods continue to call their cluster-local response service.

The existing primary GKE Ingress at `136.81.197.123` remains available until
the multi-cluster endpoint, Cloud Armor attachment, and failover test pass.

## Preconditions

Verify the controller, exports, and security policy before applying routing:

```bash
gcloud container fleet ingress describe \
  --project=gke-sre-assesment \
  --format='yaml(state,resourceState,membershipStates)'

kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  get gatewayclass gke-l7-global-external-managed-mc

kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  get serviceimport request-info-gke-request-info-service

gcloud compute security-policies describe gke-assessment-web-waf \
  --project=gke-sre-assesment
```

Both fleet membership states must be `OK`, the GatewayClass must be accepted,
the ServiceImport must exist, and the Cloud Armor policy must contain its SQLi,
XSS, and default rules.

## Review without changing the cluster

Use server-side dry-run against the primary config cluster:

```bash
kubectl apply \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --dry-run=server \
  -k kubernetes/multi-cluster-gateway
```

## Deploy in controlled order

Attach Cloud Armor to the generated ServiceImport first:

```bash
kubectl apply \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  -f kubernetes/multi-cluster-gateway/gcp-backend-policy.yaml
```

Then create the Gateway and route:

```bash
kubectl apply \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  -f kubernetes/multi-cluster-gateway/gateway.yaml

kubectl apply \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  -f kubernetes/multi-cluster-gateway/http-route.yaml
```

Google Cloud load-balancer provisioning can take several minutes. Watch the
resources without reapplying them:

```bash
kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  get gcpbackendpolicy,gateway,httproute

kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  describe gateway request-info-global

kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  describe httproute request-info-global
```

Do not continue until the Gateway is programmed, the route is accepted, and
the backend policy reports that it is attached.

## Functional validation

Read the Gateway address and send a request with a unique correlation ID:

```bash
GATEWAY_IP=$(kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  get gateway request-info-global \
  -o jsonpath='{.status.addresses[0].value}')

curl -i \
  -H 'X-Request-ID: multi-cluster-gateway-001' \
  "http://${GATEWAY_IP}/"
```

Repeat requests and preserve responses showing both `gke-primary` and
`gke-secondary`. Then test Cloud Armor with a safe synthetic query and expect
HTTP 403 while a normal request continues returning HTTP 200.

## Rollback

Delete routing from the outside inward, while retaining the known-good
single-cluster Ingress:

```bash
kubectl delete \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  -f kubernetes/multi-cluster-gateway/http-route.yaml

kubectl delete \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  -f kubernetes/multi-cluster-gateway/gateway.yaml

kubectl delete \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  -f kubernetes/multi-cluster-gateway/gcp-backend-policy.yaml
```

Wait for Google Cloud to remove the generated forwarding rule, target proxy,
URL map, backend services, health checks, and network endpoint groups before
destroying the Terraform-managed Cloud Armor policy or disabling fleet
features. `ServiceExport` can remain while troubleshooting routing because it
does not expose a public endpoint by itself.

## HTTPS follow-up

This first endpoint is intentionally HTTP-only to isolate multi-region routing,
Cloud Armor, and failover validation. The assignment's final HTTPS design
requires an owned DNS name and certificate. Add TLS only after HTTP succeeds;
do not remove the requirement from the final traceability report.
