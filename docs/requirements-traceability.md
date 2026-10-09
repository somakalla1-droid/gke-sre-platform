# Assessment Requirements Traceability

**Baseline:** [GKE SRE Open-Book Assessment Requirements](assignment-requirements.md)  
**Last assessed:** October 9, 2026

**Purpose:** Track evidence, planned work, and approved free-tier constraints without treating planned configuration as deployed evidence.

## Status definitions

- **Complete** — implemented and verified in the relevant environment.
- **In progress** — partially implemented, with verified evidence but remaining delivery work.
- **Prepared** — committed configuration exists, but has not yet been applied or proven in GCP.
- **Pending** — required for the assessment but not yet implemented.
- **Production recommendation** — intentionally documented rather than implemented in the assessment environment.

## Executive assessment

The solution remains aligned with the assignment. The foundation, two regional GKE clusters, both applications in each cluster, global multi-cluster HTTP routing and failover, Cloud Armor WAF, load-driven HPA behavior, structured log export, BigQuery queries, and Grafana dashboard are deployed and verified. No required item has been abandoned; HTTPS/DNS, CI/CD hardening, and the remaining tracing, security, and DR controls are later phases.

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
| Artifact Registry | Complete | Docker repository `gke-apps` in `us-central1`; repository-scoped node image-pull IAM in both clusters; immutable response tag `02f767d7e54d` and request tag `2311689d057c` are deployed in both regions | Retain image and IAM evidence. |
| CI build and publish lifecycle | Complete | Both app workflows test, vet, lint Helm, build, authenticate through GitHub OIDC/Workload Identity Federation, and publish commit-SHA images to GAR; both post-merge runs and immutable digests are recorded in the [publishing evidence](evidence/github-actions-image-publishing.md) | Keep deployment as a separately reviewed CD action; update action runtimes before the announced runner migration. |
| Workload Identity | In progress | Response-service pods in both clusters use `response-service-workload`, a secret-scoped principal, and the GKE Secret Manager CSI volume; pod readiness verifies the mount without reading its value | Add workload identities for other services only when they require GCP access. |
| Accessible application endpoint | Complete | Existing primary Ingress remains available; global multi-cluster Gateway `136.81.84.189` returns HTTP 200 to Application A while Application B remains private and cluster-local | Retain both endpoints until HTTPS and final rollback evidence are complete. |
| Global load balancing / MCI or MCS | Complete | MCS exports from both clusters feed an accepted global external multi-cluster Gateway; health checks covered four Pods, normal traffic returned HTTP 200, and controlled regional failover succeeded | Retain rollback and cleanup evidence. |
| Trusted HTTPS and external DNS | Production recommendation | The Gateway has a global public IP and verified HTTP routing; the owner has no public domain or delegated subdomain, so trusted certificate authorization and public DNS delegation cannot be completed honestly | Follow the documented [HTTPS/DNS production design and free-tier disposition](https-dns-disposition.md) when an owned domain becomes available. |
| Cloud Armor and geographic routing | Complete | Terraform-managed SQLi/XSS WAF is attached and returned HTTP 403 for a safe test; the global Gateway used healthy backends in both regions and failed over successfully | Retain security-policy, backend-health, and cleanup evidence. |
| Cloud NAT | Production recommendation | Current assessment nodes have external addresses and do not require NAT for egress; adding NAT alone would not prove private-node egress | A production private-cluster design uses Private Google Access, Cloud NAT, egress policy, and NAT logging as documented in the [network disposition](https-dns-disposition.md). |
| Cloud Logging and Cloud Monitoring | In progress | GKE logging/monitoring are enabled; both applications emit correlated JSON logs; public request records were verified in Cloud Logging; both expose `/metrics` | Capture workload/node telemetry and Grafana evidence. |
| BigQuery log analysis | Complete | Terraform-managed dataset and filtered sink; scoped writer IAM; real success/error/delay records; verified correlation, error-rate, and p50/p95/p99 queries | Connect the appropriate data source to Grafana and retain final dashboard evidence. |
| Grafana dashboard with four required panels | Complete | Version-controlled dashboard JSON; verified BigQuery and Cloud Monitoring data sources; live errors, restarts, p50/p95/p99 latency, CPU, and memory panels; sanitized screenshot | Revoke temporary dashboard credentials during final cleanup after all assessment evidence is complete. |
| Log-based error and latency analysis | Complete | Exported records contain `request_id`, `status_code`, and `latency_ms`; controlled queries returned a 25% sample error rate and p50/p95/p99 values | Use representative traffic for final dashboard screenshots; controlled evidence is not a production baseline. |
| Cloud Trace, Profiler, and Error Reporting | In progress | Trace, Telemetry, Profiler, and Error Reporting APIs plus scoped workload IAM are applied; Application B uses authenticated OTLP and produced a verified primary-cluster server span, trace-correlated logs, and Error Reporting group `CIPGhZW4v5DPiQE`; see the [response-service evidence](evidence/response-service-observability.md) | Confirm a live profile, instrument Application A, prove the three-span distributed trace, and repeat on the secondary cluster. |
| Cross-service request flow | Complete | Application A calls B using Kubernetes internal DNS in both clusters; `assessment-flow-001` and `secondary-flow-001` produced HTTP 200 and correlated JSON logs | Add trace propagation when Cloud Trace is introduced. |
| Security controls | In progress | Non-root distroless images; read-only root filesystem; dropped Linux capabilities; Shielded Nodes; Secure Boot; scoped artifact access; Workload Identity; Secret Manager CSI; attached Cloud Armor SQLi/XSS WAF with verified HTTP 403 | Binary Authorization remains pending; private-cluster production rationale must be documented. |
| Backups and disaster recovery | Pending | Two-cluster layout and cleanup strategy documented | Add a realistic assessment recovery runbook; document Cloud SQL/GKE/Artifact Registry backup production patterns. |
| Troubleshooting scenario | Complete | [Response-service capacity incident](evidence/response-service-capacity-incident.md): initial Helm rollback, event-based diagnosis, Terraform node-capacity correction, numeric distroless identity correction, and successful retry | Retain commands and event evidence for final handoff. |
| Architecture, setup, design-rationale, and cleanup documentation | In progress | Project plan, state operations, foundation evidence, primary readiness, configuration inventory, multi-cluster failover evidence, HPA scaling evidence, and keyless CI publication evidence | Add architecture diagram, deployment/operations runbooks, BigQuery schema/query guide, DR/security rationale, and cleanup evidence. |

## Completed application-evidence corrections

These corrections were completed before collecting the current application and log evidence:

1. Structured request logs include `status_code`, `latency_ms`, `request_id`, and appropriate severity.
2. Helm charts provide ConfigMap-driven configuration, and the response service demonstrates Secret Manager CSI without copying secret contents into Kubernetes.
3. Immutable commit-derived images are published for both applications. GitHub OIDC automation remains part of the CI/CD hardening work.
4. Application A calls Application B and propagates `X-Request-ID`. Application B now emits verified server spans; W3C trace-context propagation from Application A remains pending.

## Current delivery gate

The next delivery actions are Application A trace propagation, live Profiler evidence, the secondary observability rollout, DR documentation, architecture diagram, and final cleanup evidence. HTTPS/DNS and Cloud NAT have documented production dispositions and explicit revisit criteria.

## Free-tier handling

The supplied assignment explicitly permits skipping unavailable free-tier features. Any item skipped for access, quota, or budget reasons must have all three of the following in the final submission:

1. The reason it could not be implemented in this environment.
2. The intended production service and configuration.
3. Evidence that the closest feasible assessment alternative was tested.
