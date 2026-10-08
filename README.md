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

## Repositories

- [Platform](https://github.com/somakalla1-droid/gke-sre-platform)
- [Request info service](https://github.com/somakalla1-droid/gke-request-info-service)
- [Response service](https://github.com/somakalla1-droid/gke-response-service)

## Current phase

Desktop readiness, repository setup, the Terraform foundation, the primary GKE cluster, Secret Manager integration, and the response-service deployment are complete. The first response-service Helm release exposed a real scheduling-capacity incident; the Terraform-managed two-node correction and a numeric distroless security-context fix were verified by a successful two-pod deployment. The next controlled stage is deploying the request service and establishing the Application A-to-B flow.
