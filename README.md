# GKE SRE Assessment

This workspace contains the platform engineering portion of the GKE SRE assessment.

## Documentation

- [Original assignment requirements](docs/assignment-requirements.md)
- [Requirements traceability](docs/requirements-traceability.md)
- [Desktop and cloud readiness](docs/desktop-readiness.md)
- [Assessment project plan](docs/project-plan.md)
- [Configuration inventory](docs/configuration-inventory.md)
- [Bootstrap log](docs/bootstrap-log.md)
- [Terraform state operations](docs/terraform-state.md)
- [Foundation deployment evidence](docs/evidence/foundation-deployment.md)
- [Primary cluster deployment evidence](docs/evidence/primary-cluster-deployment.md)
- [Primary cluster readiness](docs/primary-cluster-readiness.md)
- [Google Secret Manager demo design](docs/secret-manager-demo.md)
- [Response-service capacity incident](docs/evidence/response-service-capacity-incident.md)
- [Response-service deployment evidence](docs/evidence/response-service-deployment.md)
- [Request-service deployment and cross-service flow evidence](docs/evidence/request-service-deployment.md)
- [External GKE Ingress runbook](docs/runbooks/external-gke-ingress.md)
- [Multi-cluster Gateway readiness](docs/multi-cluster-gateway-readiness.md)
- [BigQuery application-log export](docs/observability-bigquery.md)
- [BigQuery log-export evidence](docs/evidence/bigquery-log-export.md)
- [Grafana Cloud data-source setup](docs/grafana-cloud.md)
- [Grafana assessment dashboard](docs/grafana-dashboard.md)
- [Grafana dashboard evidence](docs/evidence/grafana-dashboard.md)
- [Secondary GKE cluster readiness](docs/secondary-cluster-readiness.md)

## Repositories

- [Platform](https://github.com/somakalla1-droid/gke-sre-platform)
- [Request info service](https://github.com/somakalla1-droid/gke-request-info-service)
- [Response service](https://github.com/somakalla1-droid/gke-response-service)

## Current phase

Desktop readiness, repository setup, the Terraform foundation, two regional GKE clusters, Secret Manager integration, both applications in both clusters, the primary public GKE Ingress, BigQuery log analysis, and the Grafana dashboard are complete. Application A calls Application B through internal Kubernetes DNS and emits correlated structured logs in both regions. The next controlled stage is multi-cluster Gateway and failover validation, beginning with its Gateway API prerequisite.
