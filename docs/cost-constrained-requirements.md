# Cost-Constrained Requirements and Production Disposition

**Assessed:** October 11, 2026  
**Project:** `gke-sre-assesment`  
**Account type:** Personal Google Cloud free trial

## Purpose

The assignment permits features unavailable in the GCP free tier to be
skipped. This document identifies requirements for which recurring cost or
cost risk influenced the assessment design, explains what was implemented
instead, and records the production implementation and revisit criteria.

The word *deferred* is intentional. Most Google Cloud services below were
technically available to the project, but deploying them solely for a
short-lived, stateless demonstration would have consumed free-trial credit
without materially improving the evidence. They must not be described as
technically unavailable.

Prices below are public US list-price examples observed on October 11, 2026.
Actual charges depend on location, usage, discounts, and future price changes.

## Cost-influenced decisions

| Requirement or production control | Cost consideration | Assessment decision and closest verified alternative | Production implementation and revisit criterion |
| --- | --- | --- | --- |
| Regional GKE clusters | GKE charges a `$0.10` per-cluster-hour management fee. The `$74.40` monthly GKE free-tier credit applies to one zonal Standard or Autopilot cluster, not a regional Standard cluster. Regional Standard node pools also require careful total-node configuration because multi-zone placement can materially increase VM count and cross-zone traffic. | Two zonal Standard clusters were deployed in different regions with three `e2-medium` nodes each. This proves cross-region application redundancy and global failover while retaining the zonal free-tier benefit for one cluster. It does not provide regional control-plane or multi-zone node HA within either region. | Use regional clusters with node pools distributed across at least three zones, autoscaling limits, disruption budgets, and a reviewed cost estimate. Revisit when production availability objectives require within-region HA or when additional trial budget is approved. |
| Backup for GKE | Backup management is approximately `$0.012328767` per protected namespace-hour, or about `$9` per namespace-month, plus backup storage and possible cross-region transfer. Protecting the one application namespace independently in both clusters would begin around `$18` per month before storage. | No PersistentVolumes or customer database exist. Regional failover, deterministic Terraform/Helm recreation, immutable images, Secret Manager, and protected Terraform state were tested instead. This is recovery evidence, not a claim that GKE Backup is deployed. | Create a backup plan per required recovery boundary, store backups outside the failure domain, and run restore tests. Revisit immediately if PersistentVolumes, stateful workloads, or a formal cluster-state RPO is introduced. |
| Private nodes with Cloud NAT | Public NAT has gateway-hour, NAT-IP-hour, processed-data, and internet-transfer charges. Two regional NAT paths also add operational cost and quota considerations. The existing external node IPv4 addresses are themselves billable, so NAT is not automatically more expensive; it requires a complete design comparison rather than adding a gateway to public nodes. | The assessment nodes retain external addresses. Both subnets enable Private Google Access, but Cloud NAT was not added because it would not be on the egress path until the clusters were converted or recreated with private nodes. | Use private nodes, Private Google Access, one resilient NAT design per region, explicit egress policy, NAT logging, and port/capacity monitoring. Revisit when private-node conversion is approved and compare NAT costs with the external IPv4 charges it replaces. |
| Broad VPC, firewall, load-balancer, and control-plane log retention/export | Cloud Logging charges by stored volume after applicable free allotments, and vended network telemetry can have separate pricing. VPC Flow Logs can produce far more data than the application evidence needed for this assessment; exporting it also adds destination storage and query cost. | GKE logging and monitoring remain enabled. Applications emit structured correlated logs, while a narrow sink exports request-completion logs to BigQuery with 30-day table expiration. Live metrics, traces, profiles, errors, and the four required Grafana panels were verified. Broad network-log export is not claimed. | Enable sampled VPC Flow Logs, firewall logging, load-balancer logging, control-plane logs, retention tiers, exclusions, and budget alerts according to security and compliance requirements. Revisit when the production logging volume and retention objectives are known. |
| Secondary Artifact Registry repository or replicated promotion target | Artifact Registry provides the first `0.5 GiB-month` of storage per billing account without charge; additional storage and some cross-region transfer are billable. A continuously maintained second repository also requires promotion, signing, retention, and cleanup automation. | Both clusters pull attested immutable digests from the shared `us-central1` repository. Source code and keyless CI can rebuild the images. This leaves a documented regional registry dependency even though the present repository is only about 83 MB and a second copy would likely remain inside the current storage free allotment. | Publish and attest approved digests to a second region or use a tested rebuild/promotion workflow. Revisit when Artifact Registry regional loss is inside the required recovery scope. |
| Dedicated internal load balancers for east-west application traffic | Internal load balancers add forwarding-rule and processed-data charges and would create extra infrastructure for traffic that remains inside each Kubernetes cluster. | Application A reaches Application B through a private Kubernetes `ClusterIP` Service and cluster-local DNS. This path was verified in both regions and during regional failover. No application B endpoint is public. | Introduce an internal Application Load Balancer only for cross-cluster, cross-VPC, hybrid, or policy-driven consumers that cannot use cluster-local service discovery. |
| Multi-region Terraform-state and evidence replication | Additional storage is inexpensive at this scale but creates ongoing storage, operation, retention, and possibly transfer charges. | The GCS state bucket is regional with uniform access, public-access prevention, versioning, and seven-day soft delete. Four independent prefixes reduce the state blast radius. Repository documentation and sanitized evidence remain in GitHub. | Select a state/evidence location and retention policy aligned with organizational RPO, residency, and regional-outage requirements. Revisit before treating the environment as production. |

## Constraints that are not primarily cost-related

The following omissions must not be justified as free-tier cost savings.

| Requirement | Actual constraint | Closest assessment evidence | Revisit criterion |
| --- | --- | --- | --- |
| Trusted public HTTPS and Cloud DNS | The owner has no public domain or delegated subdomain. A public zone for an unowned name would not establish DNS authority, and a managed certificate could not complete domain authorization. Cloud DNS is low cost, Certificate Manager includes a free certificate tier, and the existing load balancer already incurs its base cost. | The global HTTP Gateway, stable public IP, healthy multi-region backends, Cloud Armor, normal traffic, failover, and recovery were verified. | An owned domain or delegated subdomain becomes available. Follow the [HTTPS/DNS production design](https-dns-disposition.md). |
| Folder hierarchy and Dev/Ops/SRE IAM groups | This personal account has no Google Cloud organization, governed folder hierarchy, or enterprise identity groups. | A dedicated project and least-privilege workload, node, CI publisher, signer, Grafana, and service-agent identities are deployed. | Move the project into an organization landing zone and bind group identities when organizational authority exists. |
| Private Service Access | There is no Cloud SQL, Memorystore, or other private service-producer consumer. Reserving a peering range alone would not test application connectivity. | The applications are stateless, and their in-cluster communication is private. | A managed service requiring private IP connectivity is introduced. |
| Separate load-balancer and operations subnets | The deployed global Gateway uses container-native Pod backends and does not require a proxy-only subnet for this topology. Separate operations workloads are not deployed. | Dedicated cluster subnets and isolated Pod and Service secondary ranges exist in both regions. | A regional proxy load balancer, centralized operations tier, or organizational network standard requires them. |
| Explicit organization firewall policies | Standard GKE and Gateway controllers create the required data-plane and health-check paths; no organization hierarchy is available for hierarchical firewall policy. | Public traffic is restricted to the intended Gateway path, Application B remains cluster-local, and Cloud Armor protects the HTTP backend. | Apply centrally owned hierarchical policies when the project joins an organization landing zone. |

## Cost references

- [GKE pricing](https://cloud.google.com/kubernetes-engine/pricing)
- [Cloud NAT pricing](https://cloud.google.com/nat/pricing)
- [VPC and external IPv4 pricing](https://cloud.google.com/vpc/pricing)
- [Google Cloud Observability pricing](https://cloud.google.com/products/observability/pricing)
- [Artifact Registry pricing](https://cloud.google.com/artifact-registry/pricing)
- [Cloud Load Balancing pricing](https://cloud.google.com/load-balancing/pricing)
- [Cloud DNS pricing](https://cloud.google.com/dns/pricing)
- [Certificate Manager pricing](https://cloud.google.com/certificate-manager/pricing)

## Examiner-facing conclusion

The assessment prioritized evidence that directly demonstrated the requested
SRE capabilities: two-region operation, multi-pod services, autoscaling,
global health-based failover, observability, workload identity, secret access,
WAF protection, and signed-image admission. Recurring services that would
mainly protect persistent state or enterprise boundaries absent from this demo
were documented with production designs and explicit revisit criteria.

This disposition explains scope; it does not claim that an undeployed control
exists. A production readiness review should treat every deferred item above
as open until its stated revisit criterion is resolved.
