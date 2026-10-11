# HTTPS, DNS, and Network-Service Disposition

## HTTPS decision

The original assessment stopped at a verified public HTTP endpoint because no
owned hostname was available. That constraint has now been removed with the
free DuckDNS hostname `gke-sre-assessment.duckdns.org`.

The repository contains the reviewed implementation for browser-trusted HTTPS:

- Terraform creates a user-owned global static IPv4 address named
  `gke-sre-assessment-gateway-ip`.
- Terraform creates a Google-managed SSL certificate named
  `gke-sre-assessment-gateway-cert` for the DuckDNS hostname.
- The multi-cluster Gateway binds to the named address and terminates TLS on an
  HTTPS listener on port 443.
- The existing HTTP listener remains during verification and rollback.
- The same `HTTPRoute` attaches to both listeners and continues to route to the
  multi-cluster `ServiceImport` protected by Cloud Armor.

DuckDNS is authoritative only for the public `A` record. Its account token is
not needed by Terraform or Kubernetes and must never be committed, placed in a
command history, or stored in Terraform state.

The live environment must not be marked HTTPS-complete until the Terraform and
Gateway changes are applied, the DuckDNS record points to the new static IP,
the managed certificate reports `ACTIVE`, and a hostname-based HTTPS request
returns HTTP 200. Follow the
[HTTPS and DuckDNS cutover runbook](runbooks/https-duckdns.md).

## Why a new static address is required

The current address `136.81.84.189` belongs to a GKE-controller-created Compute
Engine address with a generated name. Importing that controller-owned resource
into Terraform would create competing owners. The cutover therefore allocates
a dedicated Terraform-owned address and explicitly references its name from the
Gateway. This makes the DNS target stable across later Gateway reconciliation
or recreation.

## Verified baseline before HTTPS cutover

- The global external multi-cluster Gateway serves HTTP at `136.81.84.189`.
- `gke-sre-assessment.duckdns.org` resolves to that baseline address.
- A hostname-based HTTP request returns the Application A response and the
  nested Application B response.
- Multi-Cluster Services exports the request service from both GKE clusters.
- Controlled primary-region withdrawal returned HTTP 200 from the secondary
  cluster, and recovery restored both regions.
- Cloud Armor is attached to the global backend and blocked a safe SQLi test
  with HTTP 403.

## Cloud NAT decision

The assessment clusters currently use nodes with external addresses for
outbound access, so Cloud NAT is not on their active egress path. Adding Cloud
NAT without converting the clusters to private nodes would create another
billable resource without proving the intended private-egress design.

The production design should use private GKE nodes, Private Google Access for
Google APIs, and Cloud NAT for controlled internet egress. NAT logging,
explicit egress firewall policy, capacity, and port allocation should be
monitored. That conversion is intentionally deferred because it changes the
cluster network model and is not required to prove the verified multi-cluster
application flow.

## Private Service Access decision

Private Service Access is not deployed because the assessment has no Cloud SQL,
Memorystore, or other private service-producer endpoint. Creating the peering
range without a consumer would not validate an application path. If a
production managed service requires private IP connectivity, reserve a
non-overlapping producer range, establish the Service Networking connection,
apply DNS and firewall policy, and test connectivity from private workload
identities. This is separate from Private Google Access and Cloud NAT.

## References

- [Secure a GKE Gateway](https://cloud.google.com/kubernetes-engine/docs/how-to/secure-gateway)
- [Deploy GKE Gateways with static addresses](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways)
- [Google-managed SSL certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
