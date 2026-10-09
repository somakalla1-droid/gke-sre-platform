# Multi-Cluster Gateway Readiness

## Decision

Use a GKE global external **multi-cluster Gateway** for the assessment's single
public entry point. The Gateway will send requests to the healthy
`gke-request-info-service` Pods in `gke-primary` and `gke-secondary`. Each
request-service instance continues to call its cluster-local response service,
so `gke-response-service` remains private.

This uses the current Kubernetes Gateway API (`Gateway`, `HTTPRoute`, and
`ServiceExport`) rather than the earlier `MultiClusterIngress` API. It satisfies
the assignment's MCI/MCS intent through GKE Multi-cluster Services while using
Google's recommended API for a new deployment.

## Verified prerequisites

| Requirement | Observed state |
| --- | --- |
| GKE versions | Both clusters run `1.35.8-gke.1225000` |
| Network | Both clusters are VPC-native and use `gke-assessment-vpc` |
| HTTP load balancing add-on | Enabled on both clusters |
| Workload Identity Federation for GKE | Enabled on both clusters |
| Namespace and Service sameness | `assessment-apps` and the request Service have matching names in both clusters |
| Cluster health | Three Ready nodes and two ready request replicas in each cluster |
| gcloud version | `587.0.0`, above the documented fleet-registration minimum |

The GKE Hub API is not yet enabled, neither cluster is registered to a fleet,
and no multi-cluster controller is enabled. Those are intentional pending
changes, not failures.

## Ordered implementation

GKE documents strict initialization ordering for multi-cluster Gateway. Perform
the work in these reviewable stages:

1. Enable `CHANNEL_STANDARD` Gateway API through the shared Terraform GKE
   module, apply the primary and secondary roots separately, and verify the
   single-cluster GatewayClasses in both clusters.
2. Create an isolated `multi-cluster` Terraform root that enables the required
   APIs, registers both clusters in one fleet, enables Multi-cluster Services,
   grants the Google-managed controller its required IAM role, and enables the
   multi-cluster Gateway controller with `gke-primary` as the config cluster.
3. Verify both fleet memberships, feature states, and the multi-cluster
   GatewayClasses before applying any routing resources.
4. Add an optional `ServiceExport` to the request-service chart and deploy it
   to both clusters. Do not export the response service.
5. Apply the global external `Gateway` and `HTTPRoute` in the primary config
   cluster and wait for its public address and healthy backends.
6. Test normal routing and controlled backend withdrawal/restoration. Preserve
   request IDs and logs as failover evidence.
7. After the multi-cluster endpoint is proven, remove the old single-cluster
   Ingress and confirm its load-balancer resources are deleted.

The config cluster is a control point, not a traffic-path dependency. A config
cluster API outage prevents reconciliation, but an already provisioned Google
Cloud load balancer continues serving traffic. A regional config cluster would
be preferred for production; this assessment reuses the existing zonal primary
cluster to avoid a third cluster.

## Cost boundary

As of the readiness review, GKE charges standalone Multi Cluster Gateway and
Multi Cluster Ingress usage at **$3 per direct backend Pod per month**, prorated
in five-minute increments. Four request-service Pods across the two clusters
therefore represent approximately **$12 per month** while exported as direct
Gateway backends. Load-balancer resources and traffic are charged separately.

Enabling the Gateway API CRDs on the existing clusters does not itself create a
load balancer or a billable multi-cluster backend. Billing begins in later
stages when the multi-cluster feature and exported Gateway backend are active.
Keep the feature only long enough to collect evidence, then include it in the
final Terraform/Kubernetes cleanup.

## DNS and TLS

DNS and a certificate are not required for the initial HTTP endpoint and
failover test. A production HTTPS design should reserve a global IP, map a DNS
name to it, attach a certificate, and redirect HTTP to HTTPS. The assessment
will document this production path if no owned DNS name is available.

## Rollback

Rollback proceeds from the traffic layer inward:

1. Delete the `HTTPRoute` and `Gateway`, then verify Google Cloud removes their
   forwarding rule, IP, URL map, backend services, health checks, and NEGs.
2. Remove `ServiceExport` from both request-service releases.
3. Disable the multi-cluster Gateway and MCS fleet features.
4. Remove fleet memberships.
5. Disable only APIs that are no longer used by another project component.
6. Leave Gateway API enabled on the clusters unless a reviewed Terraform
   change explicitly disables it; installed CRDs alone do not expose traffic.

The existing primary Ingress stays available during migration and provides a
known-good rollback endpoint until the multi-cluster endpoint passes all tests.

## Terraform review result

The prerequisite configuration validates in both cluster roots. Refresh-only
planning against the deployed state produced the same bounded action for each
cluster:

```text
Plan: 0 to add, 1 to change, 0 to destroy.
```

The sole action is an in-place update of `google_container_cluster.this` that
adds `gateway_api_config.channel = "CHANNEL_STANDARD"`. No node pool, workload,
network, IAM, or cluster replacement is planned. Create fresh saved plans from
merged `main` immediately before applying them.

## Primary references

- [Prepare your environment for multi-cluster Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-environment-multi-cluster-gateways)
- [Deploy an external multi-cluster Gateway](https://cloud.google.com/kubernetes-engine/docs/how-to/deploy-external-multi-cluster-gateway)
- [Choose your multi-cluster load-balancing API](https://cloud.google.com/kubernetes-engine/docs/concepts/choose-mc-lb-api)
- [GKE pricing](https://cloud.google.com/kubernetes-engine/pricing)
