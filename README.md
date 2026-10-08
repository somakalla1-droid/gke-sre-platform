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

## Repositories

- [Platform](https://github.com/somakalla1-droid/gke-sre-platform)
- [Request info service](https://github.com/somakalla1-droid/gke-request-info-service)
- [Response service](https://github.com/somakalla1-droid/gke-response-service)

## Current phase

Desktop readiness, repository setup, application foundations, and the Terraform foundation are complete. The deployed foundation includes the required APIs, custom VPC, two regional VPC-native subnets, and the Docker Artifact Registry repository. The next controlled stage is planning and applying the primary GKE cluster before publishing and deploying either application.
