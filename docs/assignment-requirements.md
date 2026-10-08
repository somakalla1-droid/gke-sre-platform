# GKE SRE Open-Book Assessment Requirements

## Assignment instructions

- Completion window: one week.
- Submission method: share the personal Git repository link.
- Features unavailable in the GCP free tier may be skipped.

## Required assessment evidence

- A working cluster with an accessible application endpoint.
- A screenshot or export of the Grafana dashboard.
- Sample BigQuery queries demonstrating log analysis.
- A troubleshooting scenario documenting one issue encountered and how it was resolved.

## End-to-end architecture write-up

Build and document a GCP project with two GKE clusters, two web applications, multi-pod deployment, and full observability.

## 1. Project structure and governance

Provision a new GCP project following organizational guardrails and landing-zone standards.

### Project-level configuration

- Resource hierarchy: Folder → Project.
- IAM roles for Development, Operations, SRE, and CI/CD.
- VPC creation with segregated subnets for GKE, load balancers, and monitoring/operations.
- Centralized logging and monitoring sinks using Cloud Logging and Cloud Monitoring.

### Networking

- Shared VPC, optional when an enterprise networking team centrally manages ingress and egress.
- Private Service Access for Google APIs.
- Cloud NAT for outbound internet egress from clusters.
- Firewall rules for cluster node pools and services.

## 2. GKE cluster architecture

Deploy two Google Kubernetes Engine clusters to support high availability, environment separation, or region-based redundancy.

### Cluster 1 — primary example

- Region: `us-central1` as an example.
- Mode: GKE Standard or Autopilot, depending on the operating model.
- Node pools:
  - General-purpose pool for web workloads.
  - Optional separate pool for system workloads such as ingress or a service mesh.

### Cluster 2 — secondary example

- Region: `us-east1` or another disaster-recovery region.
- Use the same node-pool and configuration pattern to maintain symmetry.
- Possible deployment strategies:
  - Active/active.
  - Active/passive failover.
  - Blue/green or canary deployments.

### Cluster networking

- VPC-native clusters using alias IP ranges.
- A dedicated subnet per cluster, such as `gke-primary-subnet` and `gke-secondary-subnet`.
- Cloud DNS for internal and external records.
- Internal load balancers for east-west communication.

## 3. Application deployment design

Deploy two independent web applications to both clusters.

### Web Application A

- Stateless microservice.
- Kubernetes Deployment with multiple pods using a ReplicaSet/Deployment.
- Configuration stored in ConfigMaps and Secrets.
- Horizontal Pod Autoscaling based on CPU or custom metrics.

### Web Application B

- Stateless application that may use GCP services such as Pub/Sub, Cloud SQL, or Memorystore (Redis).
- Replicated across clusters to provide resilience.

### Ingress and traffic distribution

Depending on the selected global strategy, use a global external HTTPS load balancer:

- Use Multi-Cluster Ingress (MCI) or Multi-Cluster Services (MCS).
- Use a single global IP to route traffic to the nearest healthy cluster.
- Use health checks to provide cluster failover.

### Inter-service communication

Optionally use Anthos Service Mesh for:

- Mutual TLS.
- Traffic shaping, including canary and blue/green releases.
- Distributed-tracing hooks.

## 4. Customer traffic: end-to-end flow

Document how external customer traffic reaches the web applications.

### Step 1 — DNS resolution

- The customer accesses an application URL such as `https://www.yourapp.com`.
- Cloud DNS maps the domain to the global load-balancer IP.

### Step 2 — global load balancer

- The customer's request reaches the Google global load balancer.
- The load balancer performs:
  - SSL termination at the edge.
  - URI-based routing, if needed.
  - WAF and threat inspection using Cloud Armor.
  - Geographic load balancing across clusters.

### Step 3 — traffic routing to GKE clusters

- The load balancer forwards traffic to cluster-specific network endpoint groups (NEGs).
- Multi-Cluster Ingress provides:
  - Proximity routing to the closest cluster.
  - Failover when a cluster is unavailable.

### Step 4 — GKE ingress controller

- The cluster ingress controller receives the request. This may be GKE Ingress or an NGINX/Anthos Service Mesh ingress.
- The ingress controller forwards the request to the appropriate Kubernetes Service.

### Step 5 — Service to pods

- A Kubernetes Service, such as `ClusterIP` or `NodePort` behind a NEG, load-balances across multiple pods.
- Pod replicas provide:
  - Resilience.
  - Horizontal scaling.
  - Rolling updates with zero downtime.

### Step 6 — application response

- The application processes the request.
- The response returns through: Pods → Service → Ingress → Load Balancer → Customer.
- Latency, logs, and traces are collected automatically.

## 5. Observability: logging, monitoring, and tracing

Implement an end-to-end observability stack using GCP-native capabilities.

### Cloud Logging

- Collect container logs through the GKE logging agent.
- Collect ingress, load-balancer, VPC, and firewall logs.
- Use a centralized logging bucket or export logs to a SIEM.

### Cloud Monitoring

Collect metrics for:

- Pod CPU and memory usage.
- Node health.
- HPA scaling events.
- Ingress and load-balancer metrics, including latency, `5xx` errors, and request volume.

### BigQuery and Grafana

- Configure Cloud Logging to export logs to BigQuery.
- Configure log exports for:
  - Application logs.
  - GKE cluster logs, including control-plane and node logs.
- Use cloud-hosted Grafana.
- Create a Grafana dashboard containing at least four panels:
  - Application error rate over time, queried from BigQuery.
  - Pod restart counts by namespace.
  - Request latency percentiles: p50, p95, and p99.
  - CPU and memory utilization trends.

### Cloud Trace

- Provide distributed tracing across services.
- Show the latency breakdown for each request hop.

### Cloud Profiler

- Provide CPU and memory profiling for live applications.

### Error Reporting

- Automatically aggregate application exceptions.

### Optional enhancements

- Prometheus and Grafana through Managed Service for Prometheus.
- Anthos Service Mesh telemetry.
- Uptime checks and synthetic monitoring.

## 6. High availability and disaster recovery

- Use two GKE clusters for cross-regional redundancy.
- Use multi-cluster ingress for automatic failover.
- Handle state with cross-regional storage, such as:
  - Cloud SQL high availability.
  - Memorystore replication.
  - Firestore multi-region.
- Configure backups such as:
  - Cloud SQL automated backups and point-in-time recovery.
  - GKE `etcd` backups.
  - Artifact Registry backup policies.

## 7. Security

- Use Workload Identity for secure service-account mapping.
- Store secrets in Secret Manager.
- Use private GKE clusters where appropriate; this is optional.
- Configure Cloud Armor WAF rules.
- Use Binary Authorization for image attestation.

## 8. Deliverables

- Infrastructure as Code using Terraform to reproduce the complete setup.
- Documentation containing:
  - An architecture diagram.
  - Step-by-step setup instructions.
  - The BigQuery schema and sample queries used in Grafana.
  - Design decisions and their rationale.

## 9. Summary of the intended solution

The completed project should deliver:

- A new GCP project.
- Two GKE clusters supporting high availability or a multi-region strategy.
- Two web applications deployed with scalable, multi-pod replicas.
- Global load balancing with intelligent traffic distribution.
- Full observability across logs, metrics, traces, and errors.
- Built-in security, resilience, and compliance controls.

## Source note

This document is a Markdown transcription and normalization of the assessment supplied as photographed email pages. Formatting and wording have been standardized for readability without changing the intended technical requirements. Implementation status and project-specific decisions are tracked separately in the project plan and requirements traceability documentation.
