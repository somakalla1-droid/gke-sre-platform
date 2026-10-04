# GKE SRE Assessment Project Plan

**Prepared:** October 3, 2026  
**Delivery window:** One week  
**Cloud project:** `gke-sre-assesment`  
**Primary objective:** Build a reproducible, cost-conscious GCP environment with two GKE clusters, two multi-replica web applications, global traffic design, and end-to-end observability.

## 1. Assessment outcomes

The completed assessment must provide:

- A working GKE-hosted application endpoint.
- Two GKE clusters representing cross-region redundancy.
- Two independent web applications deployed to both clusters.
- Multiple pod replicas and horizontal scaling configuration.
- A documented customer request path from DNS/load balancer to pod and back.
- Cloud Logging and Cloud Monitoring coverage.
- Application and GKE logs available for analysis in BigQuery.
- A Grafana dashboard with at least four required panels.
- A screenshot or export of the Grafana dashboard.
- Sample BigQuery queries demonstrating log analysis.
- One genuine troubleshooting scenario and its resolution.
- Terraform that can reproduce the infrastructure.
- Architecture, setup, operations, security, disaster recovery, design-decision, and cleanup documentation.
- Personal Git repository links for review.

## 2. Delivery model

Use three repositories to reflect realistic team ownership:

| Repository | Owner | Responsibilities |
| --- | --- | --- |
| `gke-sre-platform` | Platform/SRE | Terraform, networking, clusters, IAM, observability, BigQuery, Grafana, platform manifests, documentation |
| `gke-request-info-service` | Application Team A | Source, tests, image, Helm chart/manifests, CI workflow |
| `gke-response-service` | Application Team B | Source, tests, image, Helm chart/manifests, CI workflow |

The platform repository is the primary assessment entry point and links to both application repositories.

## 3. Target architecture

```text
                         Customer
                            |
                    Global HTTPS endpoint
                            |
               Global load-balancing design
                     /              \
             Primary region     Secondary region
             Zonal GKE cluster  Zonal GKE cluster
                /       \          /       \
             App A     App B     App A     App B
             2+ pods   2+ pods   2+ pods   2+ pods
                \       /          \       /
                 Cloud Logging and Monitoring
                            |
                    Log Router / Sink
                            |
                         BigQuery
                            |
                    Grafana dashboards
```

### Proposed locations

- Primary: `us-central1`, using a single zone.
- Secondary: `us-east1`, using a single zone.
- Artifact Registry: colocated with the primary workloads or deliberately documented as a shared regional registry.

Zonal clusters are used to control assessment costs. The production design will explain when regional clusters are appropriate.

## 4. Scope decisions

### Implement and verify

- Dedicated VPC and cluster subnets.
- VPC-native GKE networking with secondary pod and service ranges.
- Two small zonal GKE clusters.
- Artifact Registry for both application images.
- Workload Identity Federation for GKE.
- Namespaces and least-privilege Kubernetes service accounts.
- Two stateless applications with health endpoints and structured logs.
- Kubernetes Deployments with at least two replicas.
- Services, resource requests/limits, probes, PodDisruptionBudgets, and HPAs.
- Cloud Logging, Cloud Monitoring, BigQuery log analysis, and Grafana dashboard.
- A reachable application endpoint and documented request flow.
- Terraform state protection and reproducible deployment/cleanup commands.

### Demonstrate briefly if credits and quotas allow

- Both clusters running simultaneously.
- Multi-cluster service discovery or ingress/failover behavior.
- Removal of one backend/cluster to demonstrate health-based routing.
- Trace propagation across application requests.

### Document as production recommendations

- Shared VPC and organizational folder hierarchy.
- Regional GKE clusters.
- Cloud Armor policies.
- Binary Authorization and image attestation.
- Private clusters plus controlled egress.
- Anthos/Cloud Service Mesh.
- Cloud SQL HA, Memorystore replication, and other stateful services.
- Backup for GKE and cross-region backup policies.
- Enterprise SIEM export.

The photographed assignment permits skipping features unavailable in the GCP free tier. Every skipped feature will have a rationale and production implementation path.

## 5. Application design

Both applications should be deliberately small so the assessment evaluates platform engineering rather than application complexity.

### Application A: request information service

- Returns application name, version, cluster/region indicator, pod name, request ID, and timestamp.
- Exposes `/`, `/healthz`, `/readyz`, and `/metrics`.
- Emits structured JSON request and error logs.
- Supports an optional controlled error endpoint for observability testing.

### Application B: downstream response service

- Returns a simple independent response or is called by Application A to demonstrate service-to-service traffic.
- Propagates request and trace identifiers.
- Exposes health and metrics endpoints.
- Can introduce a controlled delay for latency-dashboard testing.

### Common delivery requirements

- Multi-stage, non-root container image.
- Unit tests and container smoke test.
- Semantic image tags using commit SHA and release tag.
- Read-only root filesystem where practical.
- No embedded credentials or environment-specific configuration.
- GitHub Actions workflow for test, build, and Artifact Registry publish.

## 6. Infrastructure work breakdown

### Phase 0 — Readiness and controls

**Goal:** Establish a safe workstation and cloud baseline.

Tasks:

- Complete the remaining items in the desktop readiness runbook.
- Verify the intended GCP project and billing linkage.
- Verify the $25 budget and alert thresholds.
- Confirm relevant regional CPU, IP, and GKE quotas.
- Configure GitHub authentication.
- Create the three repositories and branch protections.
- Add `.gitignore`, secret-scanning guidance, CODEOWNERS, and contribution rules.

Exit criteria:

- All required CLI tools respond successfully.
- GitHub repositories are accessible.
- No credential material exists inside the repositories.

### Phase 1 — Application foundations

**Goal:** Produce two independently buildable and observable containers.

Tasks:

- Scaffold Applications A and B.
- Add health, readiness, metrics, error, and latency-test endpoints.
- Add structured logging and request/trace correlation.
- Add tests and Dockerfiles.
- Build and test images locally.
- Create CI workflows without deploying yet.

Exit criteria:

- Both test suites pass.
- Both images run locally as non-root users.
- Health endpoints and structured logs are verified.

### Phase 2 — Terraform foundation

**Goal:** Build reusable, reviewable infrastructure as code.

Tasks:

- Establish Terraform provider and version constraints.
- Create environment configuration and reusable modules.
- Manage required APIs explicitly.
- Create the VPC, primary subnet, secondary subnet, and alias ranges.
- Create Artifact Registry.
- Create service accounts and minimal IAM bindings.
- Add lifecycle, validation, and output definitions.
- Add formatting, validation, linting, and security checks.

Exit criteria:

- `terraform fmt -check` passes.
- `terraform validate` passes.
- The saved plan contains only expected resources.
- No secret or billing identifier is committed.

### Phase 3 — GKE clusters and application deployment

**Goal:** Deploy both applications with resilient pod configurations.

Tasks:

- Create the primary small zonal cluster.
- Configure Workload Identity and cluster access.
- Create namespaces and platform policies.
- Push images to Artifact Registry.
- Deploy both applications with at least two replicas.
- Configure Services, probes, resources, HPAs, and PodDisruptionBudgets.
- Validate rolling updates and pod self-healing.
- Create and validate the secondary cluster only after the primary is stable.
- Deploy the same application versions to the secondary cluster.

Exit criteria:

- Both applications are healthy in both clusters.
- Replica, rescheduling, and rolling-update behavior is demonstrated.
- Kubernetes events show no unresolved warnings.

### Phase 4 — Ingress and customer traffic flow

**Goal:** Provide an accessible endpoint and explain every request hop.

Tasks:

- Establish the lowest-cost viable external endpoint.
- Configure health checks and backend readiness.
- Evaluate Multi-Cluster Services/Ingress against quota and trial constraints.
- Demonstrate cluster-aware routing or document the exact production configuration if the feature is unavailable.
- Record the end-to-end flow:
  1. DNS or endpoint resolution.
  2. Global/external load balancer.
  3. Cluster network endpoint group or ingress.
  4. Kubernetes Service.
  5. Application pod.
  6. Response path and telemetry collection.

Exit criteria:

- At least one externally accessible application endpoint works.
- Health-check behavior is visible.
- The architecture diagram and traffic walkthrough match the deployed system.

### Phase 5 — Observability and analytics

**Goal:** Deliver logs, metrics, traces, errors, and required evidence.

Tasks:

- Confirm collection of application, workload, node, ingress, and relevant control-plane logs.
- Configure a filtered log sink or linked analytics path for BigQuery.
- Define a documented BigQuery schema/data model.
- Create sample SQL for errors, pod restarts, latency, request volume, and cluster comparison.
- Connect Grafana to the selected Google Cloud/BigQuery data sources.
- Create at least these four panels:
  - Application error rate over time.
  - Pod restart count by namespace.
  - Request latency percentiles: p50, p95, and p99.
  - CPU and memory utilization trends.
- Add useful panels for request volume, availability, and cluster/region distribution if time permits.
- Exercise controlled errors, latency, and pod restart scenarios.
- Verify Cloud Trace, Profiler, and Error Reporting where supported by the applications and free-trial scope.
- Export the Grafana dashboard JSON and capture a screenshot.

Exit criteria:

- The four required Grafana panels contain real test data.
- BigQuery sample queries return meaningful results.
- Logs correlate through request IDs and, where available, trace IDs.

### Phase 6 — Resilience, recovery, and security

**Goal:** Validate failure behavior and document production safeguards.

Tasks:

- Delete a pod and show automatic replacement.
- Perform a rolling deployment without customer-visible downtime.
- Briefly test cluster/backend unavailability if multi-cluster routing is implemented.
- Document recovery objectives, state assumptions, cluster recreation, registry retention, and backup strategy.
- Review IAM, Workload Identity, secret handling, network exposure, container privileges, and image provenance.
- Record which Cloud Armor, Binary Authorization, private-cluster, and backup controls are documented-only.

Exit criteria:

- At least one application and one platform resilience test are recorded.
- Security and disaster-recovery gaps are explicitly documented rather than implied.

### Phase 7 — Evidence, handoff, and cleanup

**Goal:** Produce a reviewer-friendly submission and stop cloud spend.

Tasks:

- Write the main README with prerequisites and a guided deployment path.
- Finalize the architecture diagram and design decisions.
- Record setup, validation, operations, troubleshooting, and cleanup commands.
- Document one real issue encountered, its symptoms, investigation, root cause, remediation, and prevention.
- Link the two application repositories from the platform repository.
- Capture sanitized screenshots and command evidence.
- Run final tests and Terraform validation.
- Destroy temporary GKE and load-balancing resources after evidence is collected.
- Verify no unexpected billable resources remain.

Exit criteria:

- A reviewer can understand, reproduce, validate, and destroy the solution from the documentation.
- All requested assessment evidence is present.
- Expensive runtime resources have been removed.

## 7. One-week schedule

| Day | Primary milestone | Expected evidence |
| --- | --- | --- |
| 1 | Readiness, repositories, application scaffolds | Tool verification, repo structure, passing local tests |
| 2 | Terraform network, registry, IAM, primary GKE | Terraform plan/apply records, healthy primary cluster |
| 3 | Application deployments and secondary GKE | Images, manifests, multi-replica workloads in both clusters |
| 4 | External routing and failure behavior | Reachable endpoint, traffic-flow validation, failover notes |
| 5 | Logging, BigQuery, Grafana, traces | SQL results, four dashboard panels, dashboard export |
| 6 | Security, resilience, troubleshooting, documentation | Test evidence, runbooks, architecture and decision records |
| 7 | Final review, screenshots, cleanup | Submission checklist, repository links, destroyed runtime resources |

If quota or feature access blocks multi-cluster routing, stop spending time after a bounded investigation. Preserve the two-cluster Terraform and deployments, document the blocker, and provide the exact production configuration that would complete the feature.

## 8. Testing strategy

### Application tests

- Unit tests for request handling and health behavior.
- Structured-log shape validation.
- Container startup and non-root execution test.
- Controlled error and latency endpoint tests.

### Infrastructure tests

- Terraform formatting and validation.
- Terraform lint/security scan.
- Kubernetes manifest or Helm linting.
- Cluster connectivity and namespace checks.
- Deployment availability and rollout checks.
- Service endpoint and health-check validation.

### Resilience tests

- Pod deletion and recovery.
- Rolling update.
- HPA response to bounded test load, if metrics are available.
- Cluster/backend withdrawal and restoration, if multi-cluster routing is implemented.

### Observability tests

- Generate normal traffic, errors, and latency.
- Confirm application logs in Cloud Logging and BigQuery.
- Confirm dashboard panels display the generated signals.
- Correlate a request across logs and trace data where supported.

## 9. Required evidence inventory

Store sanitized evidence in the platform repository under `docs/evidence/`:

- Architecture diagram.
- Terraform validation and plan summary.
- Cluster and node status.
- Workload, service, HPA, and ingress status.
- Reachable application response.
- Grafana dashboard screenshot and JSON export.
- BigQuery SQL file and representative sanitized results.
- Logging, trace, profiler, and error-reporting evidence where implemented.
- Resilience-test results.
- Troubleshooting case study.
- Final cloud cleanup verification.

Do not capture tokens, cookies, private keys, billing identifiers, or unredacted account data in screenshots or committed output.

## 10. Completion checklist

- [ ] Desktop readiness fully complete.
- [ ] Three repositories created and linked.
- [ ] Two applications implemented, tested, and containerized.
- [ ] Terraform provisions the approved environment.
- [ ] Two GKE clusters validated.
- [ ] Both applications run with multiple replicas in both clusters.
- [ ] External endpoint validated.
- [ ] Traffic routing and failover behavior demonstrated or explicitly documented.
- [ ] Cloud Logging and Monitoring validated.
- [ ] BigQuery log analysis and sample queries delivered.
- [ ] Grafana dashboard includes the four required panels.
- [ ] Trace, profiler, and error-reporting status documented.
- [ ] Security and disaster-recovery design documented.
- [ ] Real troubleshooting scenario documented.
- [ ] Architecture diagram, setup guide, and design rationale complete.
- [ ] Screenshots and exports sanitized.
- [ ] Temporary billable resources destroyed after review evidence is collected.
