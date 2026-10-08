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

## Repositories

- [Platform](https://github.com/somakalla1-droid/gke-sre-platform)
- [Request info service](https://github.com/somakalla1-droid/gke-request-info-service)
- [Response service](https://github.com/somakalla1-droid/gke-response-service)

## Current phase

Desktop readiness, repository setup, the Terraform foundation, the primary GKE cluster, Secret Manager integration, and both primary-cluster application deployments are complete. Application A calls Application B through internal Kubernetes DNS, propagates `X-Request-ID`, and emits correlated structured logs. An external request-service Ingress is enabled but awaiting the Terraform-managed GKE HTTP load-balancing add-on; the next controlled stage is applying that correction and verifying the public endpoint.
