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
| High availability / multi-region strategy | In progress | Primary cluster is healthy; secondary design is symmetric with separate regional subnet | Demonstrate both clusters, then implement or document traffic failover. One node per cluster is an assessment cost decision, not node-level HA. |
| Two independent web applications | Prepared | Separate Git repositories, Go services, Dockerfiles, tests, Helm charts, CI validation | Publish images and deploy both apps to both clusters. |
| Multi-pod deployments, HPA, probes, PDBs, and resource limits | Prepared | Both Helm charts set two replicas, HPA, probes, PDB, and CPU/memory requests/limits | Deploy and demonstrate replica, rollout, and recovery behavior. |
| ConfigMaps and Secrets for application configuration | In progress | Both application charts now create ConfigMaps and support an optional Kubernetes Secret reference; Secret Manager Terraform is prepared | Apply the Secret Manager foundation/add-on changes and add CSI volume mounts to the response-service chart. |
| Artifact Registry | Complete | Docker repository `gke-apps` in `us-central1`; node image-pull IAM in primary/secondary module | Push immutable application images. |
| CI build and publish lifecycle | Partially prepared | Both app CI workflows test, vet, lint Helm, and build Docker images | Add GitHub OIDC/Workload Identity Federation and image publishing with commit-SHA tags. No static keys. |
| Workload Identity | In progress | Enabled in the cluster module; Secret Manager plan grants the response-service Kubernetes service-account principal secret-scoped access | Apply the planned Secret Manager IAM binding and demonstrate the mounted secret file from the workload. |
| Accessible application endpoint | Pending | Services are ClusterIP and no cluster is deployed | Add the lowest-cost external endpoint after primary workloads are healthy. |
| Global HTTPS load balancing / MCI or MCS | Pending | Target architecture and traffic flow documented | Investigate feature access/cost after both clusters work. If not feasible on free trial, document the exact production design and demonstrate a single-cluster external endpoint. |
| DNS, Cloud Armor, geographic routing, and Cloud NAT | Production recommendation / pending decision | Documented target architecture; no resources deployed | Cloud Armor and NAT introduce cost/complexity. Implement only if budget and feature access permit; otherwise document the production path and test the accessible endpoint without them. |
| Cloud Logging and Cloud Monitoring | Prepared | GKE module enables Kubernetes logging and monitoring; applications emit JSON logs and expose `/metrics` | Verify real workload, node, ingress, and application telemetry after deployment. |
| BigQuery log analysis | Pending | BigQuery API enabled | Create dataset and filtered log sink, then add sanitized sample SQL and results. |
| Grafana dashboard with four required panels | Pending | Required panels documented in the project plan | Configure a data source; build panels for errors, restarts, p50/p95/p99 latency, and CPU/memory; export JSON and capture a screenshot. |
| Log-based error and latency analysis | Needs correction before deployment | Applications emit `request_id` and `latency_ms` JSON fields | Add HTTP status and error severity to structured request logs. Current controlled-error responses are logged as `INFO`, so a general error-rate query would be unreliable. |
| Cloud Trace, Profiler, and Error Reporting | Pending | Not instrumented | Add OpenTelemetry/Cloud Trace and determine free-trial feasibility for Profiler and Error Reporting; document any unsupported feature explicitly. |
| Cross-service request flow | Prepared design | Both apps support request IDs; response service is independent | Make Application A call Application B, propagate a request/trace ID, and verify the complete flow after deployment. |
| Security controls | Partially prepared | Non-root distroless images; read-only root filesystem; dropped Linux capabilities; Shielded Nodes; Secure Boot; artifact access is scoped | Add Secret Manager usage, workload identity bindings, and security/DR design documentation. Private clusters, Cloud Armor, and Binary Authorization remain documented production controls unless budget permits. |
| Backups and disaster recovery | Pending | Two-cluster layout and cleanup strategy documented | Add a realistic assessment recovery runbook; document Cloud SQL/GKE/Artifact Registry backup production patterns. |
| Troubleshooting scenario | Pending | No real cluster incident has occurred yet | Record a genuine issue encountered during deployment, investigation steps, remediation, and prevention. |
| Architecture, setup, design-rationale, and cleanup documentation | In progress | Project plan, state operations, foundation evidence, primary readiness, and configuration inventory | Add architecture diagram, deployment/operations runbooks, BigQuery schema/query guide, DR/security rationale, and cleanup evidence. |

## Mandatory corrections before application evidence

These are not deviations from the assignment, but they are necessary to make the later evidence meaningful:

1. Add `status_code` and an error-level severity to the structured application log record. This supports the required error-rate query and Grafana panel.
2. Add a ConfigMap and a Secret interface to both Helm charts. A Secret may remain empty or reference Secret Manager until a genuine secret is required, but the configuration model must be demonstrable.
3. Add immutable image publishing to both application CI workflows using GitHub OIDC and Workload Identity Federation.
4. Make Application A call Application B and propagate `X-Request-ID`; later add trace propagation when Cloud Trace instrumentation is introduced.

## Current delivery gate

The next approved infrastructure action is to apply the reviewed primary-cluster plan. After cluster health is verified, complete the four mandatory corrections above before deploying applications. This order keeps the cluster troubleshooting surface small while ensuring later logging, BigQuery, and Grafana evidence conforms to the assignment.

## Free-tier handling

The supplied assignment explicitly permits skipping unavailable free-tier features. Any item skipped for access, quota, or budget reasons must have all three of the following in the final submission:

1. The reason it could not be implemented in this environment.
2. The intended production service and configuration.
3. Evidence that the closest feasible assessment alternative was tested.
