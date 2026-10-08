# Assessment Requirements Traceability

**Baseline:** [GKE SRE Open-Book Assessment Requirements](assignment-requirements.md)  
**Last assessed:** October 7, 2026  
**Purpose:** Track evidence, planned work, and approved free-tier constraints without treating planned configuration as deployed evidence.

## Status definitions

- **Complete** — implemented and verified in the relevant environment.
- **In progress** — partially implemented, with verified evidence but remaining delivery work.
- **Prepared** — committed configuration exists, but has not yet been applied or proven in GCP.
- **Pending** — required for the assessment but not yet implemented.
- **Production recommendation** — intentionally documented rather than implemented in the assessment environment.

## Executive assessment

The solution is aligned with the assignment. The foundation layer is complete, and the primary-cluster plan is ready to apply. No required item has been abandoned; most runtime, traffic, observability, and evidence requirements are simply not due until later phases.

The intentional assessment choices are one zonal Standard cluster at a time, one `e2-medium` node per cluster, and a shared primary-region Artifact Registry repository. These choices control free-trial spend while retaining the required two-cluster, two-application target design. They must be clearly distinguished from the production recommendations in the final handoff.

## Requirement matrix

| Requirement | Status | Current evidence | Remaining work or rationale |
| --- | --- | --- | --- |
| New GCP project and billing controls | Complete | `gke-sre-assesment`, free-trial credits, budget alerts, configuration inventory | Continue monitoring spend during runtime phases. |
| Terraform-reproducible infrastructure | In progress | Protected remote state; applied and drift-verified foundation and primary-cluster roots; prepared secondary root | Apply/verify the secondary cluster, then add observability and traffic resources to Terraform. |
| VPC with separated GKE subnets and alias ranges | Complete | Custom VPC; primary/secondary subnets; distinct node, pod, and service ranges | Add any explicit firewall rules required by ingress or private networking later. |
| Two GKE clusters in separate regions | In progress | `gke-primary` is deployed and healthy in `us-central1-a`; `gke-secondary` root targets `us-east1-b` | Apply and verify the secondary cluster after primary application deployment is stable. |
| High availability / multi-region strategy | In progress | Primary cluster is healthy; two nodes were required for response-service replicas after a genuine scheduling incident, and a reviewed third-node increase is required for two request-service replicas; secondary design is symmetric with a separate regional subnet | Demonstrate both clusters, then implement or document traffic failover. |
| Two independent web applications | In progress | Both applications are published and deployed to `gke-primary`; Application A calls Application B through the internal service DNS | Deploy both applications to the secondary cluster. |
| Multi-pod deployments, HPA, probes, PDBs, and resource limits | In progress | Both services have verified two-pod deployments, HPA (2–5), probes, PDB, and resource limits | Demonstrate load-driven HPA behavior, rollout, and recovery. |
| ConfigMaps and Secrets for application configuration | In progress | Response deployment verifies ConfigMap injection and a GKE Secret Manager CSI volume, with no secret value printed or mirrored into a Kubernetes Secret | Deploy request service configuration; retain evidence of GSM rotation/mount behavior as needed. |
| Artifact Registry | Complete | Docker repository `gke-apps` in `us-central1`; node image-pull IAM in primary/secondary module; immutable response image tag `02f767d7e54d` is published | Publish the request-service image. |
| CI build and publish lifecycle | Partially prepared | Both app CI workflows test, vet, lint Helm, and build Docker images | Add GitHub OIDC/Workload Identity Federation and image publishing with commit-SHA tags. No static keys. |
| Workload Identity | In progress | The deployed response-service pod uses `response-service-workload`, a secret-scoped principal, and the GKE Secret Manager CSI volume; pod readiness verifies the mount without reading its value | Add workload identities for other services only when they require GCP access. |
| Accessible application endpoint | In progress | Request-service Ingress chart is merged and enabled, but the primary cluster omitted the HTTP load-balancing add-on so no address was provisioned | Apply the reviewed Terraform add-on correction, wait for the external address, and test the public HTTP endpoint. |
| Global HTTPS load balancing / MCI or MCS | In progress | The request-service Ingress is designed to create a single-cluster external Application Load Balancer; Application B remains private | Enable the add-on and verify HTTP by external IP. DNS and a certificate are still required for HTTPS; multi-cluster routing follows secondary deployment. |
| DNS, Cloud Armor, geographic routing, and Cloud NAT | Production recommendation / pending decision | Documented target architecture; no resources deployed | Cloud Armor and NAT introduce cost/complexity. Implement only if budget and feature access permit; otherwise document the production path and test the accessible endpoint without them. |
| Cloud Logging and Cloud Monitoring | In progress | GKE module enables Kubernetes logging and monitoring; both deployed applications emit correlated JSON logs and expose `/metrics` | Verify logs in Cloud Logging and collect workload/node telemetry evidence after an endpoint is added. |
| BigQuery log analysis | Pending | BigQuery API enabled | Create dataset and filtered log sink, then add sanitized sample SQL and results. |
| Grafana dashboard with four required panels | Pending | Required panels documented in the project plan | Configure a data source; build panels for errors, restarts, p50/p95/p99 latency, and CPU/memory; export JSON and capture a screenshot. |
| Log-based error and latency analysis | Needs correction before deployment | Applications emit `request_id` and `latency_ms` JSON fields | Add HTTP status and error severity to structured request logs. Current controlled-error responses are logged as `INFO`, so a general error-rate query would be unreliable. |
| Cloud Trace, Profiler, and Error Reporting | Pending | Not instrumented | Add OpenTelemetry/Cloud Trace and determine free-trial feasibility for Profiler and Error Reporting; document any unsupported feature explicitly. |
| Cross-service request flow | Complete for primary cluster | Application A calls B using Kubernetes internal DNS; `assessment-flow-001` produced HTTP 200 and the same request ID in both JSON logs | Repeat after secondary deployment; add trace propagation when Cloud Trace is introduced. |
| Security controls | Partially prepared | Non-root distroless images; read-only root filesystem; dropped Linux capabilities; Shielded Nodes; Secure Boot; artifact access is scoped | Add Secret Manager usage, workload identity bindings, and security/DR design documentation. Private clusters, Cloud Armor, and Binary Authorization remain documented production controls unless budget permits. |
| Backups and disaster recovery | Pending | Two-cluster layout and cleanup strategy documented | Add a realistic assessment recovery runbook; document Cloud SQL/GKE/Artifact Registry backup production patterns. |
| Troubleshooting scenario | Complete | [Response-service capacity incident](evidence/response-service-capacity-incident.md): initial Helm rollback, event-based diagnosis, Terraform node-capacity correction, numeric distroless identity correction, and successful retry | Retain commands and event evidence for final handoff. |
| Architecture, setup, design-rationale, and cleanup documentation | In progress | Project plan, state operations, foundation evidence, primary readiness, and configuration inventory | Add architecture diagram, deployment/operations runbooks, BigQuery schema/query guide, DR/security rationale, and cleanup evidence. |

## Mandatory corrections before application evidence

These are not deviations from the assignment, but they are necessary to make the later evidence meaningful:

1. Add `status_code` and an error-level severity to the structured application log record. This supports the required error-rate query and Grafana panel.
2. Add a ConfigMap and a Secret interface to both Helm charts. A Secret may remain empty or reference Secret Manager until a genuine secret is required, but the configuration model must be demonstrable.
3. Add immutable image publishing to both application CI workflows using GitHub OIDC and Workload Identity Federation.
4. Make Application A call Application B and propagate `X-Request-ID`; later add trace propagation when Cloud Trace instrumentation is introduced.

## Current delivery gate

The next approved delivery action is to create observable workload evidence and an accessible endpoint for the primary cluster. Then continue with the secondary cluster and multi-cluster routing requirements.

## Free-tier handling

The supplied assignment explicitly permits skipping unavailable free-tier features. Any item skipped for access, quota, or budget reasons must have all three of the following in the final submission:

1. The reason it could not be implemented in this environment.
2. The intended production service and configuration.
3. Evidence that the closest feasible assessment alternative was tested.
