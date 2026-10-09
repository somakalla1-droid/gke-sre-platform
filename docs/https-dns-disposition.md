# HTTPS, External DNS, and Cloud NAT Disposition

## Assessment decision

Trusted public HTTPS and external Cloud DNS are documented as a production
implementation rather than deployed in this assessment environment. The
assessment owner does not own a public domain or delegated subdomain. The
assignment explicitly permits features unavailable in the GCP free tier to be
skipped when the limitation is documented.

This is a domain-ownership constraint, not a missing Gateway capability. A
Cloud DNS public zone requires a domain obtained from a registrar, and a
Google-managed certificate requires public authorization for the requested
domain. Creating a zone for an unowned name would not delegate the public DNS
namespace, and Certificate Manager could not complete domain validation.

The assessment does not use a shared wildcard DNS service or a self-signed
certificate as a substitute. Neither demonstrates ownership, reliable renewal,
or a browser-trusted customer endpoint.

## Closest feasible verified implementation

The domain-independent portions of the requested design are deployed and
tested:

- A global external multi-cluster Gateway has public IP `136.81.84.189`.
- Multi-Cluster Services exports the request service from both GKE clusters.
- The generated backend had two healthy Pod endpoints in each region.
- Normal traffic returned HTTP 200 through the global load balancer.
- A controlled primary-region withdrawal returned HTTP 200 from the secondary
  cluster, and recovery restored both regions.
- Cloud Armor is attached to the global backend and blocked a safe SQLi test
  with HTTP 403.
- Application B remains private behind cluster-local Kubernetes DNS.

This proves global load balancing, geographic backend selection, health-based
failover, WAF enforcement, and the application request path. Only customer DNS
resolution and browser-trusted TLS termination are omitted.

## Production HTTPS and DNS implementation

When an owned domain or delegated subdomain becomes available, the production
change should be reviewed and delivered in this order:

1. Choose a hostname such as `assessment.example.com` and confirm control of
   its authoritative DNS.
2. Preserve a stable global address for the Gateway and create a public `A`
   record pointing the hostname to that address.
3. Enable Certificate Manager and create a global DNS authorization for the
   hostname.
4. Publish the authorization `CNAME` record in the authoritative DNS zone.
5. Create a Google-managed certificate, certificate-map entry, and certificate
   map after domain authorization is valid.
6. Attach the certificate map to the multi-cluster Gateway with
   `networking.gke.io/certmap` and add an HTTPS listener on port 443. Do not use
   both the certificate-map annotation and `tls.certificateRefs` on the same
   Gateway.
7. Restrict the `HTTPRoute` to the chosen hostname and retain Cloud Armor on the
   imported backend.
8. Add an explicit HTTP-to-HTTPS redirect or remove the public HTTP listener
   after HTTPS health and rollback behavior are verified.
9. Test certificate validity, hostname routing, normal HTTP 200 behavior, WAF
   blocking, and regional failover through the HTTPS hostname.

Google documentation used for this production path:

- [Set up DNS records for a domain name](https://cloud.google.com/dns/docs/set-up-dns-records-domain-name)
- [Certificate Manager domain authorization](https://cloud.google.com/certificate-manager/docs/domain-authorization)
- [Secure a GKE Gateway](https://cloud.google.com/kubernetes-engine/docs/how-to/secure-gateway)

## Cloud NAT decision

The assessment clusters currently use nodes with external addresses for
outbound access, so Cloud NAT is not on their active egress path. Adding Cloud
NAT without converting the clusters to private nodes would create another
billable resource without proving the intended private-egress design.

The production design should use private GKE nodes, Private Google Access for
Google APIs, and Cloud NAT for controlled internet egress. NAT logging,
explicit egress firewall policy, capacity, and port allocation should be
monitored. That conversion is intentionally deferred because it changes the
cluster network model and is not required to prove the already verified
multi-cluster application flow.

## Revisit criteria

Reopen this decision if either of these becomes available:

- An owned domain or delegated subdomain suitable for public assessment use.
- Approval to purchase/register a domain and operate its authoritative DNS.

Until then, the public HTTP endpoint remains temporary assessment evidence and
must be removed during final cleanup.
