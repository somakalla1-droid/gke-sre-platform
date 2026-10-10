# Assessment Requirements Traceability

**Baseline:** [GKE SRE Open-Book Assessment Requirements](assignment-requirements.md)  
**Last assessed:** October 10, 2026

**Purpose:** Track evidence, planned work, and approved free-tier constraints without treating planned configuration as deployed evidence.

## Status definitions

- **Complete** — implemented and verified in the relevant environment.
- **In progress** — partially implemented, with verified evidence but remaining delivery work.
- **Prepared** — committed configuration exists, but has not yet been applied or proven in GCP.
- **Pending** — required for the assessment but not yet implemented.
- **Production recommendation** — intentionally documented rather than implemented in the assessment environment.

## Executive assessment

The solution remains aligned with the assignment. The foundation, two regional GKE clusters, both applications in each cluster, global multi-cluster HTTP routing and failover, Cloud Armor WAF, load-driven HPA behavior, structured log export, BigQuery queries, Grafana dashboard, distributed tracing, Error Reporting, and live profiling are deployed and verified. No required item has been abandoned; HTTPS/DNS and Cloud NAT have explicit production dispositions, and remaining security, architecture, and cleanup controls are later phases.

The intentional assessment choices are two zonal Standard clusters with three `e2-medium` nodes each and a shared primary-region Artifact Registry repository. Three nodes per cluster were required to schedule the GKE system workloads and both two-replica applications with their declared resources and disruption budgets. These choices must be clearly distinguished from the regional-cluster and private-networking recommendations in the final production handoff.

## Requirement matrix

| Requirement | Status | Current evidence | Remaining work or rationale |
| --- | --- | --- | --- |
| New GCP project and billing controls | Complete | `gke-sre-assesment`, free-trial credits, budget alerts, configuration inventory | Continue monitoring spend during runtime phases. |
| Terraform-reproducible infrastructure | In progress | Protected remote state; applied and drift-verified foundation, primary-cluster, and secondary-cluster roots; Terraform-managed BigQuery export | Add remaining traffic and security resources to Terraform. |
| VPC with separated GKE subnets and alias ranges | Complete | Custom VPC; primary/secondary subnets; distinct node, pod, and service ranges | Add any explicit firewall rules required by ingress or private networking later. |
| Two GKE clusters in separate regions | Complete | `gke-primary` is healthy in `us-central1-a`; `gke-secondary` is healthy in `us-east1-b`; each has three Ready nodes and isolated Terraform state | Retain drift and cleanup evidence. |
| High availability / multi-region strategy | Complete | Both regional clusters run symmetric application stacks; the global Gateway had four healthy Pod backends; controlled primary endpoint withdrawal returned HTTP 200 from secondary and recovery restored both regions | Retain cleanup evidence and the [multi-cluster Gateway evidence](evidence/multi-cluster-gateway.md). |
| Two independent web applications | Complete | Both immutable images are deployed with two replicas in each cluster; Application A calls Application B through internal service DNS in both regions | Retain rollout and cleanup evidence. |
| Multi-pod deployments, HPA, probes, PDBs, and resource limits | Complete | Both services have two-pod baselines, HPA (2–5), probes, PDB, and resource limits in both clusters; a bounded primary-cluster test drove both HPAs to five desired replicas, the response service reached five available replicas, and the request service reached three before fixed node capacity prevented the remaining two | Retain the [HPA scaling evidence](evidence/hpa-scaling.md); production must pair pod autoscaling with node autoscaling or reserved capacity. |
| ConfigMaps and Secrets for application configuration | Complete | Both charts provide application configuration in both clusters; each response deployment verifies a GKE Secret Manager CSI volume, with no secret value printed or mirrored into a Kubernetes Secret | Retain IAM and cleanup evidence. |
| Artifact Registry | Complete | Docker repository `gke-apps` in `us-central1`; repository-scoped node image-pull IAM in both clusters; immutable response tag `7aa78243c6cb864d7decfe80646ded3f0641c7fe` and request tag `03ea1316292d2c605b73b67d0eb28f31d775d0ee` are deployed in both regions | Retain image and IAM evidence. |
| CI build and publish lifecycle | Complete | Both app workflows test, vet, lint Helm, build, authenticate through GitHub OIDC/Workload Identity Federation, and publish commit-SHA images to GAR; both post-merge runs and immutable digests are recorded in the [publishing evidence](evidence/github-actions-image-publishing.md) | Keep deployment as a separately reviewed CD action; update action runtimes before the announced runner migration. |
| Workload Identity | Complete | Both application Kubernetes service accounts use scoped GKE workload principals for Trace and Profiler; response-service also has secret-scoped access for its Secret Manager CSI mount; no service-account key is stored | Grant new workload roles only when an application requires another GCP API. |
| Accessible application endpoint | Complete | Existing primary Ingress remains available; global multi-cluster Gateway `136.81.84.189` returns HTTP 200 to Application A while Application B remains private and cluster-local | Retain both endpoints until HTTPS and final rollback evidence are complete. |
| Global load balancing / MCI or MCS | Complete | MCS exports from both clusters feed an accepted global external multi-cluster Gateway; health checks covered four Pods, normal traffic returned HTTP 200, and controlled regional failover succeeded | Retain rollback and cleanup evidence. |
| Trusted HTTPS and external DNS | Production recommendation | The Gateway has a global public IP and verified HTTP routing; the owner has no public domain or delegated subdomain, so trusted certificate authorization and public DNS delegation cannot be completed honestly | Follow the documented [HTTPS/DNS production design and free-tier disposition](https-dns-disposition.md) when an owned domain becomes available. |
| Cloud Armor and geographic routing | Complete | Terraform-managed SQLi/XSS WAF is attached and returned HTTP 403 for a safe test; the global Gateway used healthy backends in both regions and failed over successfully | Retain security-policy, backend-health, and cleanup evidence. |
| Cloud NAT | Production recommendation | Current assessment nodes have external addresses and do not require NAT for egress; adding NAT alone would not prove private-node egress | A production private-cluster design uses Private Google Access, Cloud NAT, egress policy, and NAT logging as documented in the [network disposition](https-dns-disposition.md). |
| Cloud Logging and Cloud Monitoring | Complete | GKE logging/monitoring are enabled; both applications emit correlated JSON logs; public request records were verified in Cloud Logging; live CPU, memory, restart, request, and latency data is retained in the Grafana evidence | Retain the [Grafana dashboard evidence](evidence/grafana-dashboard.md) and revoke temporary dashboard credentials during final cleanup. |
| BigQuery log analysis | Complete | Terraform-managed dataset and filtered sink; scoped writer IAM; real success/error/delay records; verified correlation, error-rate, and p50/p95/p99 queries | Connect the appropriate data source to Grafana and retain final dashboard evidence. |
| Grafana dashboard with four required panels | Complete | Version-controlled dashboard JSON; verified BigQuery and Cloud Monitoring data sources; live errors, restarts, p50/p95/p99 latency, CPU, and memory panels; sanitized screenshot | Revoke temporary dashboard credentials during final cleanup after all assessment evidence is complete. |
| Log-based error and latency analysis | Complete | Exported records contain `request_id`, `status_code`, and `latency_ms`; controlled queries returned a 25% sample error rate and p50/p95/p99 values | Use representative traffic for final dashboard screenshots; controlled evidence is not a production baseline. |
| Cloud Trace, Profiler, and Error Reporting | Complete | Error Reporting group `CIPGhZW4v5DPiQE`; three-span distributed traces in both clusters; trace-correlated logs; live request/response CPU profiles; and a live response heap profile are verified through scoped workload identity | Retain the [response-service](evidence/response-service-observability.md), [distributed-tracing](evidence/distributed-tracing.md), and [Cloud Profiler](evidence/cloud-profiler.md) evidence. |
| Cross-service request flow | Complete | Application A calls B using Kubernetes internal DNS in both clusters; HTTP 200, request-ID correlation, W3C trace-context propagation, and one three-span distributed trace are verified in each region | Retain the [distributed-tracing evidence](evidence/distributed-tracing.md). |
| Security controls | In progress | Non-root distroless images; read-only root filesystem; dropped Linux capabilities; Shielded Nodes; Secure Boot; scoped artifact access; Workload Identity; Secret Manager CSI; attached Cloud Armor SQLi/XSS WAF with verified HTTP 403; KMS-backed Binary Authorization attestor and audit-only policy verified in both clusters with successful rollouts and Cloud Audit Log evidence | Convert both application releases from tags to immutable digests, attest those digests, verify them in audit mode, then review enforced blocking separately; private-cluster production rationale must also be documented. |
| Backups and disaster recovery | Complete | Controlled regional failover and recovery succeeded; all four Terraform states are protected by object versioning and seven-day soft delete; both stateless stacks are reproducible from reviewed code and immutable images | Retain and exercise the [DR and backup runbook](runbooks/disaster-recovery.md); GKE Backup, Cloud SQL PITR, and a secondary GAR repository are documented production controls because no PV or database exists in the assessment. |
| Troubleshooting scenario | Complete | [Response-service capacity incident](evidence/response-service-capacity-incident.md): initial Helm rollback, event-based diagnosis, Terraform node-capacity correction, numeric distroless identity correction, and successful retry | Retain commands and event evidence for final handoff. |
| Architecture, setup, design-rationale, and cleanup documentation | In progress | Project plan, state operations, foundation evidence, primary readiness, configuration inventory, multi-cluster failover evidence, HPA scaling evidence, DR runbook, and keyless CI publication evidence | Add architecture diagram, remaining security rationale, and cleanup evidence. |

## Completed application-evidence corrections

These corrections were completed before collecting the current application and log evidence:

1. Structured request logs include `status_code`, `latency_ms`, `request_id`, and appropriate severity.
2. Helm charts provide ConfigMap-driven configuration, and the response service demonstrates Secret Manager CSI without copying secret contents into Kubernetes.
3. Immutable commit-derived images are published for both applications. GitHub OIDC automation remains part of the CI/CD hardening work.
4. Application A calls Application B and propagates both `X-Request-ID` and W3C trace context. Verified traces in each region contain the Application A server span, its outbound client span, and the Application B server span.

## Current delivery gate

The Binary Authorization audit-first rollout is complete in both clusters and documented in [Binary Authorization Audit Evidence](evidence/binary-authorization-audit.md). The next delivery action is to deploy and attest both immutable application digests while retaining `DRYRUN_AUDIT_LOG_ONLY`. The architecture diagram, remaining private-cluster security decision, and final cleanup evidence follow. HTTPS/DNS and Cloud NAT have documented production dispositions and explicit revisit criteria.

## Free-tier handling

The supplied assignment explicitly permits skipping unavailable free-tier features. Any item skipped for access, quota, or budget reasons must have all three of the following in the final submission:

1. The reason it could not be implemented in this environment.
2. The intended production service and configuration.
3. Evidence that the closest feasible assessment alternative was tested.
