# Assessment Requirements Traceability

**Baseline:** [GKE SRE Open-Book Assessment Requirements](assignment-requirements.md)  
**Last assessed:** October 8, 2026  
**Purpose:** Track evidence, planned work, and approved free-tier constraints without treating planned configuration as deployed evidence.

## Status definitions

- **Complete** — implemented and verified in the relevant environment.
- **In progress** — partially implemented, with verified evidence but remaining delivery work.
- **Prepared** — committed configuration exists, but has not yet been applied or proven in GCP.
- **Pending** — required for the assessment but not yet implemented.
- **Production recommendation** — intentionally documented rather than implemented in the assessment environment.

## Executive assessment

The solution remains aligned with the assignment. The foundation, primary cluster, two primary-cluster applications, public endpoint, structured log export, and initial BigQuery queries are deployed and verified. No required item has been abandoned; Grafana, the secondary cluster, multi-cluster routing, and the remaining security/DR controls are later phases.

The intentional assessment choices are one zonal Standard cluster at a time, one `e2-medium` node per cluster, and a shared primary-region Artifact Registry repository. These choices control free-trial spend while retaining the required two-cluster, two-application target design. They must be clearly distinguished from the production recommendations in the final handoff.

## Requirement matrix

| Requirement | Status | Current evidence | Remaining work or rationale |
| --- | --- | --- | --- |
| New GCP project and billing controls | Complete | `gke-sre-assesment`, free-trial credits, budget alerts, configuration inventory | Continue monitoring spend during runtime phases. |
| Terraform-reproducible infrastructure | In progress | Protected remote state; applied and drift-verified foundation and primary-cluster roots; Terraform-managed BigQuery export; prepared secondary root | Apply and verify the secondary cluster, then add remaining traffic and security resources to Terraform. |
| VPC with separated GKE subnets and alias ranges | Complete | Custom VPC; primary/secondary subnets; distinct node, pod, and service ranges | Add any explicit firewall rules required by ingress or private networking later. |
| Two GKE clusters in separate regions | In progress | `gke-primary` is deployed and healthy in `us-central1-a`; `gke-secondary` root targets `us-east1-b` | Apply and verify the secondary cluster after primary application deployment is stable. |
| High availability / multi-region strategy | In progress | Primary cluster is healthy; two nodes were required for response-service replicas after a genuine scheduling incident, and a reviewed third-node increase is required for two request-service replicas; secondary design is symmetric with a separate regional subnet | Demonstrate both clusters, then implement or document traffic failover. |
| Two independent web applications | In progress | Both immutable images are published and deployed to `gke-primary`; Application A calls Application B through internal service DNS | Deploy both applications to the secondary cluster. |
| Multi-pod deployments, HPA, probes, PDBs, and resource limits | In progress | Both services have verified two-pod deployments, HPA (2–5), probes, PDB, and resource limits | Demonstrate load-driven HPA behavior, rollout, and recovery. |
| ConfigMaps and Secrets for application configuration | Complete for primary | Both charts provide application configuration; response deployment verifies a GKE Secret Manager CSI volume, with no secret value printed or mirrored into a Kubernetes Secret | Repeat applicable configuration in the secondary cluster. |
| Artifact Registry | Complete | Docker repository `gke-apps` in `us-central1`; node image-pull IAM in the cluster module; immutable response tag `02f767d7e54d` and request tag `2311689d057c` are published | Reuse the repository for the secondary deployment. |
| CI build and publish lifecycle | Partially prepared | Both app CI workflows test, vet, lint Helm, and build Docker images | Add GitHub OIDC/Workload Identity Federation and image publishing with commit-SHA tags. No static keys. |
| Workload Identity | In progress | The deployed response-service pod uses `response-service-workload`, a secret-scoped principal, and the GKE Secret Manager CSI volume; pod readiness verifies the mount without reading its value | Add workload identities for other services only when they require GCP access. |
| Accessible application endpoint | Complete for primary | GKE external Ingress routes public HTTP traffic to Application A; Application B remains private; correlated A-to-B request evidence returned HTTP 200 | Retain evidence and remove the billable endpoint during cleanup. |
| Global HTTPS load balancing / MCI or MCS | In progress | A single-cluster external Application Load Balancer is verified; Application B remains private | DNS/certificate are required for HTTPS; multi-cluster routing follows secondary deployment. |
| DNS, Cloud Armor, geographic routing, and Cloud NAT | Production recommendation / pending decision | Documented target architecture; no resources deployed | Cloud Armor and NAT introduce cost/complexity. Implement only if budget and feature access permit; otherwise document the production path and test the accessible endpoint without them. |
| Cloud Logging and Cloud Monitoring | In progress | GKE logging/monitoring are enabled; both applications emit correlated JSON logs; public request records were verified in Cloud Logging; both expose `/metrics` | Capture workload/node telemetry and Grafana evidence. |
| BigQuery log analysis | Complete | Terraform-managed dataset and filtered sink; scoped writer IAM; real success/error/delay records; verified correlation, error-rate, and p50/p95/p99 queries | Connect the appropriate data source to Grafana and retain final dashboard evidence. |
| Grafana dashboard with four required panels | Pending | Required panels documented in the project plan | Configure a data source; build panels for errors, restarts, p50/p95/p99 latency, and CPU/memory; export JSON and capture a screenshot. |
| Log-based error and latency analysis | Complete | Exported records contain `request_id`, `status_code`, and `latency_ms`; controlled queries returned a 25% sample error rate and p50/p95/p99 values | Use representative traffic for final dashboard screenshots; controlled evidence is not a production baseline. |
| Cloud Trace, Profiler, and Error Reporting | Pending | Not instrumented | Add OpenTelemetry/Cloud Trace and determine free-trial feasibility for Profiler and Error Reporting; document any unsupported feature explicitly. |
| Cross-service request flow | Complete for primary cluster | Application A calls B using Kubernetes internal DNS; `assessment-flow-001` produced HTTP 200 and the same request ID in both JSON logs | Repeat after secondary deployment; add trace propagation when Cloud Trace is introduced. |
| Security controls | In progress | Non-root distroless images; read-only root filesystem; dropped Linux capabilities; Shielded Nodes; Secure Boot; scoped artifact access; Workload Identity and Secret Manager CSI with secret-scoped IAM | Cloud Armor and Binary Authorization remain pending; private-cluster production rationale must be documented. |
| Backups and disaster recovery | Pending | Two-cluster layout and cleanup strategy documented | Add a realistic assessment recovery runbook; document Cloud SQL/GKE/Artifact Registry backup production patterns. |
| Troubleshooting scenario | Complete | [Response-service capacity incident](evidence/response-service-capacity-incident.md): initial Helm rollback, event-based diagnosis, Terraform node-capacity correction, numeric distroless identity correction, and successful retry | Retain commands and event evidence for final handoff. |
| Architecture, setup, design-rationale, and cleanup documentation | In progress | Project plan, state operations, foundation evidence, primary readiness, and configuration inventory | Add architecture diagram, deployment/operations runbooks, BigQuery schema/query guide, DR/security rationale, and cleanup evidence. |

## Completed application-evidence corrections

These corrections were completed before collecting the current application and log evidence:

1. Structured request logs include `status_code`, `latency_ms`, `request_id`, and appropriate severity.
2. Helm charts provide ConfigMap-driven configuration, and the response service demonstrates Secret Manager CSI without copying secret contents into Kubernetes.
3. Immutable commit-derived images are published for both applications. GitHub OIDC automation remains part of the CI/CD hardening work.
4. Application A calls Application B and propagates `X-Request-ID`. Trace-context propagation remains part of Cloud Trace instrumentation.

## Current delivery gate

The next approved delivery action is to build the required Grafana panels from the verified logs and GKE metrics. Then continue with Cloud Armor, the secondary cluster, and multi-cluster routing.

## Free-tier handling

The supplied assignment explicitly permits skipping unavailable free-tier features. Any item skipped for access, quota, or budget reasons must have all three of the following in the final submission:

1. The reason it could not be implemented in this environment.
2. The intended production service and configuration.
3. Evidence that the closest feasible assessment alternative was tested.
