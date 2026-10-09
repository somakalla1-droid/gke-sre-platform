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
| Fleet memberships | Both regional memberships are `READY` and report current Kubernetes metadata |
| Multi-cluster Services | `ACTIVE`; both membership states are `OK` and the MCS importers are running |
| Namespace and Service sameness | `assessment-apps` and the request Service have matching names in both clusters |
| Cluster health | Three Ready nodes and two ready request replicas in each cluster |
| gcloud version | `587.0.0`, above the documented fleet-registration minimum |

The multi-cluster Gateway feature is `ACTIVE`, but its per-membership status
reports `ERROR: Lost connection`. The exported multi-cluster GatewayClasses
are therefore not available yet, and no Gateway routing resources should be
created until both membership states become `OK`.

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

After both cluster updates were applied and drift-verified, the isolated
`terraform/environments/assessment/multi-cluster` root was validated and
planned. Its initial plan is:

```text
Plan: 11 to add, 0 to change, 0 to destroy.
```

The root enables six required APIs, including the Connect Gateway API, and
manages the default fleet, two regional
cluster memberships, Multi-cluster Services, the multi-cluster Gateway
controller feature, and the controller's documented `roles/container.admin`
IAM membership. The root uses the independent remote-state prefix
`terraform/assessment/multi-cluster`. It does not create exported Services,
Gateway routing resources, a public address, or a load balancer.

### Service-agent dependency correction

The first apply successfully created the five APIs, fleet, both memberships,
and Multi-cluster Services, then stopped safely before enabling the Gateway
controller. The IAM API rejected the controller role binding because the
`multiclusteringress.googleapis.com` Google-managed service agent had not yet
been materialized. API enablement and service-agent creation are separate
eventually consistent operations.

The root now declares `google_project_service_identity` through the official
`google-beta` provider and uses its computed `member` in the IAM resource. This
creates an explicit dependency chain:

```text
API -> service identity -> controller IAM -> Gateway controller feature
```

No manual identity or IAM command is required. The successfully created
resources remain in remote state and are refreshed—not recreated—by the
corrected follow-up plan. The corrected complete model contains twelve managed
resources; only the service identity, IAM membership, and Gateway controller
feature should remain to be added after the partial apply.

### Fleet membership connectivity review

After the controller feature became `ACTIVE`, the base fleet memberships were
`READY` and MCS APIs were installed in both clusters, while the Gateway
feature's per-membership status temporarily reported `ERROR: Lost connection`.
The first diagnostic plan considered adding fleet Workload Identity authority
blocks to the existing memberships, but the provider correctly showed that
this would destroy and recreate both membership resources. That destructive
plan was rejected and must not be applied. Both GKE clusters already use the
fleet host project's GKE Workload Identity pool.

The fleet host project requires the documented MCS importer permission. The
root grants `roles/compute.networkViewer` to the fleet Workload Identity
principal `gke-mcs/gke-mcs-importer`. This read-only fleet control-plane grant
does not expose an application, create a load balancer, or grant an application
workload additional access.

### Connect Gateway prerequisite correction

After applying the MCS importer permission, Multi-cluster Services became
healthy for both memberships, but the Multi-cluster Gateway controller
continued to report `Lost connection`. Replacing only the Terraform-managed
Gateway controller feature reproduced the same error without affecting either
cluster, any application workload, or the existing primary Ingress.

The next diagnostic check found that Fleet Workload Identity was already
`ACTIVE` but the documented `connectgateway.googleapis.com` prerequisite was
not enabled. The multi-cluster Terraform root now manages this API alongside
the other fleet APIs. This is an additive project-service change; it does not
replace fleet memberships, clusters, or workloads. After applying it, verify
that both Gateway membership states are `OK` and that accepted `*-mc`
GatewayClasses appear before creating `ServiceExport`, `Gateway`, or
`HTTPRoute` resources.

### Fleet membership identity migration

Enabling the Connect Gateway API made direct Connect Gateway access to both
memberships successful, proving that the fleet can reach and authenticate to
both Kubernetes API servers. The multi-cluster Gateway controller still
reported `Lost connection`, however, and neither Membership object contained
an `authority` field. The clusters have Workload Identity Federation for GKE,
but their original Terraform registration did not enable identity on the fleet
membership itself.

The membership resources now declare their cluster issuer in an `authority`
block. Applying that configuration directly to the existing memberships would
replace them, so that destructive plan must not be applied. Instead, after this
configuration is merged, reconcile each existing membership in place with the
idempotent Google Cloud registration command and
`--enable-workload-identity`. Google documents that rerunning registration for
the same cluster, membership name, and fleet is successful and ensures
Workload Identity is enabled. After both commands finish, a fresh Terraform
plan must show no membership replacement before any further apply.

Both memberships were reconciled successfully with no replacement, remained
`READY`, and gained the expected issuer, identity provider, and fleet workload
identity pool. Terraform subsequently reported no changes. A controller
restart still reproduced `Lost connection`, which ruled out missing membership
identity as the final cause.

### Controller service-agent role correction

The Google-managed Multi-Cluster Ingress service identity existed and had the
documented `roles/container.admin` grant, but it did not have its product role,
`roles/multiclusteringress.serviceAgent`. That role contains the
`gkehub.gateway.*` permissions used to connect through Fleet Gateway as well as
the load-balancer permissions used by the hosted controller. The Terraform root
now grants this role to the computed service identity and makes the Gateway
feature depend on both controller IAM bindings.

This change adds one IAM membership. It does not replace a fleet membership,
cluster, workload, or load balancer. After applying it, verify controller
membership status and multi-cluster GatewayClasses before considering another
feature restart.

## Primary references

- [Prepare your environment for multi-cluster Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-environment-multi-cluster-gateways)
- [Deploy an external multi-cluster Gateway](https://cloud.google.com/kubernetes-engine/docs/how-to/deploy-external-multi-cluster-gateway)
- [Choose your multi-cluster load-balancing API](https://cloud.google.com/kubernetes-engine/docs/concepts/choose-mc-lb-api)
- [GKE pricing](https://cloud.google.com/kubernetes-engine/pricing)
