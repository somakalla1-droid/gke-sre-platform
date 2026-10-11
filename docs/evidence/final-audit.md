# Final Assessment Audit

**Audited:** October 11, 2026  
**Project:** `gke-sre-assesment`  
**Repositories:** platform, request-info, and response

## Outcome

All functional assessment deliverables are implemented and have retained
evidence. The deployed environment is healthy and matches all four Terraform
states. The final destructive cleanup has not been executed because evidence
review is still in progress; an ordered cleanup runbook is prepared.

## Repository state

| Repository | Audited main commit | Result |
| --- | --- | --- |
| `gke-sre-platform` | `98ea1ad7a61e627902600e90d83d1ef85870c1d3` | Clean; latest Terraform validation succeeded. |
| `gke-request-info-service` | `790b3256a60e95c20b8d17317dca4214744b5b13` | Clean tree equivalent to `origin/main`; latest CI succeeded. |
| `gke-response-service` | `08eb1da1ef88bbed3ea1a02e2fc56be677eab995` | Clean tree equivalent to `origin/main`; latest CI succeeded. |

The two application worktrees were still checked out on their merged feature
branches, but their trees exactly matched `origin/main`; the audit used those
merged contents and did not modify either repository.

## Static validation

The following checks passed locally:

- `terraform fmt -check -recursive terraform`;
- `terraform validate` for foundation, primary-cluster, secondary-cluster, and
  multi-cluster roots;
- Kustomize rendering for `kubernetes/multi-cluster-gateway`;
- JSON parsing for the version-controlled Grafana dashboard;
- `go test -race ./...` and `go vet ./...` in both applications;
- Helm lint for both charts;
- immutable `repository@sha256:digest` rendering in both charts;
- request-info `ServiceExport` rendering; and
- response Secret Manager `SecretProviderClass` rendering.

## Infrastructure drift

Read-only `terraform plan -detailed-exitcode` checks returned exit code 0 and
`No changes` for all four remote states:

| Terraform root | Drift result |
| --- | --- |
| foundation | No changes |
| primary-cluster | No changes |
| secondary-cluster | No changes |
| multi-cluster | No changes |

## Live health and function

- Fleet ingress: `ACTIVE` and Ready to use.
- Primary fleet membership: `OK`.
- Secondary fleet membership: `OK`.
- `gke-primary`: three Ready nodes.
- `gke-secondary`: three Ready nodes.
- Both applications: `2/2` available in both clusters.
- Gateway `request-info-global`: programmed at `136.81.84.189`.
- HTTPRoute `request-info-global`: present in the primary config cluster.

Request `final-audit-001` returned HTTP 200-equivalent JSON through the global
Gateway. It identified request-info version
`790b3256a60e95c20b8d17317dca4214744b5b13` and response version
`08eb1da1ef88bbed3ea1a02e2fc56be677eab995`, both in `gke-primary`, with the
same propagated request ID.

## Security and provenance

- GitHub Actions authenticates through OIDC and Workload Identity Federation.
- Publisher and signer identities are separate and least-privilege.
- Both deployments use immutable GAR digests.
- Binary Authorization is `ENFORCED_BLOCK_AND_AUDIT_LOG` and requires the
  KMS-backed release attestor.
- Fresh rollouts of both approved digests succeeded in both clusters.
- A mismatched attestation was denied with `VIOLATES_POLICY` before Pod
  creation.
- Cloud Armor is attached and has verified SQLi blocking evidence.
- Response secrets use Secret Manager CSI and workload-scoped access.

## Required evidence disposition

| Deliverable | Result |
| --- | --- |
| Working clusters and accessible endpoint | Complete |
| Two applications with multiple replicas in both regions | Complete |
| Global traffic distribution and controlled failover | Complete |
| Grafana screenshot/export and four required panels | Complete |
| BigQuery schema and sample queries | Complete |
| Logging, metrics, traces, profiles, and errors | Complete |
| Troubleshooting scenario | Complete |
| Architecture diagram and design rationale | Complete |
| Step-by-step setup instructions | Complete |
| Terraform and version-controlled workload configuration | Complete |
| Security, DR, and production-gap documentation | Complete |
| Final billable-resource cleanup | Pending owner approval after evidence review |

HTTPS/DNS, private nodes with Cloud NAT, regional clusters, stateful-data HA,
and service mesh remain explicitly documented production recommendations. They
are not represented as deployed controls.

## Remaining gate

1. Merge the final documentation corrections.
2. Complete reviewer/evidence handoff.
3. Revoke temporary Grafana credentials even if live resources remain briefly.
4. Obtain explicit approval for destructive cleanup.
5. Execute the [Assessment Cleanup Runbook](../runbooks/cleanup.md) and retain a
   final residue/cost report.

