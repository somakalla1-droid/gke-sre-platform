# Assessment Requirements Traceability

**Baseline:** [GKE SRE Open-Book Assessment Requirements](assignment-requirements.md)  
**Last assessed:** October 11, 2026

**Purpose:** Track evidence, planned work, and approved free-tier constraints without treating planned configuration as deployed evidence.

## Status definitions

- **Complete** — implemented and verified in the relevant environment.
- **In progress** — partially implemented, with verified evidence but remaining delivery work.
- **Prepared** — committed configuration exists, but has not yet been applied or proven in GCP.
- **Pending** — required for the assessment but not yet implemented.
- **Production recommendation** — intentionally documented rather than implemented in the assessment environment.

## Executive assessment

The solution remains aligned with the assignment. The foundation, two regional GKE clusters, both applications in each cluster, global multi-cluster HTTP routing and failover, Cloud Armor WAF, load-driven HPA behavior, structured log export, BigQuery queries, Grafana dashboard, distributed tracing, Error Reporting, live profiling, Secret Manager, and enforced Binary Authorization are deployed and verified. Architecture, setup, design rationale, DR, troubleshooting, and cleanup procedures are documented. No required functional item has been abandoned; HTTPS/DNS, private egress, and other production deltas have explicit dispositions. Destructive cleanup remains pending until evidence review is complete.

The intentional assessment choices are two zonal Standard clusters with three `e2-medium` nodes each and a shared primary-region Artifact Registry repository. Three nodes per cluster were required to schedule the GKE system workloads and both two-replica applications with their declared resources and disruption budgets. These choices must be clearly distinguished from the regional-cluster and private-networking recommendations in the final production handoff.

Recurring-cost decisions, low-cost prerequisite constraints, implemented
substitutes, and production revisit criteria are separated explicitly in
[Cost-Constrained Requirements and Production Disposition](cost-constrained-requirements.md).
That document does not represent deferred controls as deployed or technically
unavailable.

## Requirement matrix

| Requirement | Status | Current evidence | Remaining work or rationale |
| --- | --- | --- | --- |
| New GCP project and billing controls | Complete | `gke-sre-assesment`, free-trial credits, budget alerts, configuration inventory | Continue monitoring spend during runtime phases. |
| Terraform-reproducible infrastructure | Complete | Four protected, applied, and drift-free Terraform roots manage shared foundation, both clusters, and fleet features; Helm/Kustomize manage application and Gateway resources under the documented team-ownership boundary | Follow the [setup guide](setup-guide.md) and always apply fresh saved plans from reviewed `main`. |
| VPC with separated GKE subnets and alias ranges | Complete | Custom VPC; primary/secondary subnets; distinct node, pod, and service ranges; GKE/Gateway-managed firewall and health-check paths | Production private-node egress and explicit organizational firewall policy remain documented deltas. |
| Resource hierarchy and human IAM separation | Production recommendation | Dedicated project and least-privilege machine identities are deployed; this personal free-trial project has no organization folders or separate Dev/Ops/SRE groups | In production, place the project in the governed folder hierarchy and bind group-based roles through the organization landing zone. |
| Two GKE clusters in separate regions | Complete | `gke-primary` is healthy in `us-central1-a`; `gke-secondary` is healthy in `us-east1-b`; each has three Ready nodes and isolated Terraform state | Retain drift and cleanup evidence. |
| High availability / multi-region strategy | Complete | Both regional clusters run symmetric application stacks; the global Gateway had four healthy Pod backends; controlled primary endpoint withdrawal returned HTTP 200 from secondary and recovery restored both regions | Retain cleanup evidence and the [multi-cluster Gateway evidence](evidence/multi-cluster-gateway.md). |
| Two independent web applications | Complete | Both immutable images are deployed with two replicas in each cluster; Application A calls Application B through internal service DNS in both regions | Retain rollout and cleanup evidence. |
| Multi-pod deployments, HPA, probes, PDBs, and resource limits | Complete | Both services have two-pod baselines, HPA (2–5), probes, PDB, and resource limits in both clusters; a bounded primary-cluster test drove both HPAs to five desired replicas, the response service reached five available replicas, and the request service reached three before fixed node capacity prevented the remaining two | Retain the [HPA scaling evidence](evidence/hpa-scaling.md); production must pair pod autoscaling with node autoscaling or reserved capacity. |
| ConfigMaps and Secrets for application configuration | Complete | Both charts provide application configuration in both clusters; each response deployment verifies a GKE Secret Manager CSI volume, with no secret value printed or mirrored into a Kubernetes Secret | Retain IAM and cleanup evidence. |
| Artifact Registry | Complete | Docker repository `gke-apps` in `us-central1`; repository-scoped node image-pull IAM in both clusters; request digest `sha256:83b4a862...` and response digest `sha256:3a2343ed...` are attested and deployed in both regions | Retain image, IAM, and attestation evidence until cleanup approval. |
| CI build and publish lifecycle | Complete | Both app workflows test, vet, lint Helm, build, authenticate through GitHub OIDC/Workload Identity Federation, and publish commit-SHA images to GAR; both post-merge runs and immutable digests are recorded in the [publishing evidence](evidence/github-actions-image-publishing.md) | Keep deployment as a separately reviewed CD action; update action runtimes before the announced runner migration. |
| Workload Identity | Complete | Both application Kubernetes service accounts use scoped GKE workload principals for Trace and Profiler; response-service also has secret-scoped access for its Secret Manager CSI mount; no service-account key is stored | Grant new workload roles only when an application requires another GCP API. |
| Accessible application endpoint | Complete | Existing primary Ingress remains available; global multi-cluster Gateway `136.81.84.189` returns HTTP 200 to Application A while Application B remains private and cluster-local | Retain both endpoints until HTTPS and final rollback evidence are complete. |
| Global load balancing / MCI or MCS | Complete | MCS exports from both clusters feed an accepted global external multi-cluster Gateway; health checks covered four Pods, normal traffic returned HTTP 200, and controlled regional failover succeeded | Retain rollback and cleanup evidence. |
| Trusted HTTPS and external DNS | Production recommendation | The Gateway has a global public IP and verified HTTP routing; the owner has no public domain or delegated subdomain, so trusted certificate authorization and public DNS delegation cannot be completed honestly | Follow the documented [HTTPS/DNS production design and free-tier disposition](https-dns-disposition.md) when an owned domain becomes available. |
| Cloud Armor and geographic routing | Complete | Terraform-managed SQLi/XSS WAF is attached and returned HTTP 403 for a safe test; the global Gateway used healthy backends in both regions and failed over successfully | Retain security-policy, backend-health, and cleanup evidence. |
| Cloud NAT | Production recommendation | Current assessment nodes have external addresses and do not require NAT for egress; adding NAT alone would not prove private-node egress | A production private-cluster design uses Private Google Access, Cloud NAT, egress policy, and NAT logging as documented in the [network disposition](https-dns-disposition.md). |
| Private Service Access | Production recommendation | No private service-producer consumer such as Cloud SQL or Memorystore is deployed, so an unused peering range would not prove connectivity | Configure Service Networking, a reserved producer range, DNS, and firewall policy when a production managed service requires private IP, as documented in the [network disposition](https-dns-disposition.md). |
| Cloud Logging and Cloud Monitoring | Complete | GKE logging/monitoring are enabled; both applications emit correlated JSON logs; public request records were verified in Cloud Logging; live CPU, memory, restart, request, and latency data is retained in the Grafana evidence | Retain the [Grafana dashboard evidence](evidence/grafana-dashboard.md) and revoke temporary dashboard credentials during final cleanup. |
| BigQuery log analysis | Complete | Terraform-managed dataset and filtered sink; scoped writer IAM; real success/error/delay records; verified correlation, error-rate, and p50/p95/p99 queries | Connect the appropriate data source to Grafana and retain final dashboard evidence. |
| Grafana dashboard with four required panels | Complete | Version-controlled dashboard JSON; verified BigQuery and Cloud Monitoring data sources; live errors, restarts, p50/p95/p99 latency, CPU, and memory panels; sanitized screenshot | Revoke temporary dashboard credentials during final cleanup after all assessment evidence is complete. |
| Log-based error and latency analysis | Complete | Exported records contain `request_id`, `status_code`, and `latency_ms`; controlled queries returned a 25% sample error rate and p50/p95/p99 values | Use representative traffic for final dashboard screenshots; controlled evidence is not a production baseline. |
| Cloud Trace, Profiler, and Error Reporting | Complete | Error Reporting group `CIPGhZW4v5DPiQE`; three-span distributed traces in both clusters; trace-correlated logs; live request/response CPU profiles; and a live response heap profile are verified through scoped workload identity | Retain the [response-service](evidence/response-service-observability.md), [distributed-tracing](evidence/distributed-tracing.md), and [Cloud Profiler](evidence/cloud-profiler.md) evidence. |
| Cross-service request flow | Complete | Application A calls B using Kubernetes internal DNS in both clusters; HTTP 200, request-ID correlation, W3C trace-context propagation, and one three-span distributed trace are verified in each region | Retain the [distributed-tracing evidence](evidence/distributed-tracing.md). |
| Security controls | Complete | Non-root distroless images; read-only root filesystem; dropped Linux capabilities; Shielded Nodes; Secure Boot; scoped artifact access; Workload Identity; Secret Manager CSI; Cloud Armor SQLi/XSS WAF; separate keyless publisher/signer identities; and enforced KMS-backed Binary Authorization with a verified negative test | Retain the [Binary Authorization enforcement evidence](evidence/binary-authorization-enforcement.md); private-cluster and keyless Grafana improvements are explicit production deltas. |
| Backups and disaster recovery | Complete | Controlled regional failover and recovery succeeded; all four Terraform states are protected by object versioning and seven-day soft delete; both stateless stacks are reproducible from reviewed code and immutable images | Retain and exercise the [DR and backup runbook](runbooks/disaster-recovery.md); GKE Backup, Cloud SQL PITR, and a secondary GAR repository are documented production controls because no PV or database exists in the assessment. |
| Troubleshooting scenario | Complete | [Response-service capacity incident](evidence/response-service-capacity-incident.md): initial Helm rollback, event-based diagnosis, Terraform node-capacity correction, numeric distroless identity correction, and successful retry | Retain commands and event evidence for final handoff. |
| Architecture, setup, design-rationale, and cleanup documentation | In progress | [As-built architecture](architecture.md), [setup guide](setup-guide.md), state operations, deployment evidence, inventory, security/DR runbooks, [final audit](evidence/final-audit.md), and [cleanup runbook](runbooks/cleanup.md) | Execute destructive cleanup only after reviewer approval, then retain residue and cost evidence. |

## Completed application-evidence corrections

These corrections were completed before collecting the current application and log evidence:

1. Structured request logs include `status_code`, `latency_ms`, `request_id`, and appropriate severity.
2. Helm charts provide ConfigMap-driven configuration, and the response service demonstrates Secret Manager CSI without copying secret contents into Kubernetes.
3. Immutable commit-derived images are published for both applications. GitHub OIDC automation remains part of the CI/CD hardening work.
4. Application A calls Application B and propagates both `X-Request-ID` and W3C trace context. Verified traces in each region contain the Application A server span, its outbound client span, and the Application B server span.

## Current delivery gate

Binary Authorization now blocks noncompliant images. The two approved immutable
releases passed fresh admission and end-to-end verification in both clusters,
while a controlled mismatched attestation was rejected before Pod creation.
The audit and enforcement results are documented in
[Binary Authorization Audit Evidence](evidence/binary-authorization-audit.md)
and [Binary Authorization Enforcement Evidence](evidence/binary-authorization-enforcement.md).
The final cross-repository audit found no code, configuration, live-health, or
Terraform-drift blockers. All functional deliverables are complete. The
remaining gate is reviewer approval followed by credential revocation and the
dependency-ordered destructive cleanup. HTTPS/DNS and private-node Cloud NAT
have documented production dispositions and explicit revisit criteria.

## Free-tier handling

The supplied assignment explicitly permits skipping unavailable free-tier features. Any item skipped for access, quota, or budget reasons must have all three of the following in the final submission:

1. The reason it could not be implemented in this environment.
2. The intended production service and configuration.
3. Evidence that the closest feasible assessment alternative was tested.

The project-specific decisions satisfying this rule are recorded in
[Cost-Constrained Requirements and Production Disposition](cost-constrained-requirements.md).
