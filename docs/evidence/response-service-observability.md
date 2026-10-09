# Response-Service Observability Evidence

**Environment:** `gke-primary`, `us-central1-a`  
**Date:** October 9, 2026  
**Service:** `gke-response-service`

## Immutable release

GitHub Actions validated and published merge commit:

```text
00f622a8c44579c662aa1387f1b9e5c35cba4f4e
```

Artifact Registry resolved that tag to:

```text
sha256:89058485c6fa16ba9ee3280c03f9165d22f6d4064690e123f5dc3b770a994006
```

Helm revision 4 deployed this image with `OBSERVABILITY_ENABLED=true`. The
Deployment reached two of two available replicas with zero restarts. The
ConfigMap identified the project as `gke-sre-assesment`, cluster as
`gke-primary`, region as `us-central1`, and application version as the immutable
commit SHA.

## Cloud Trace

Trace `ed0d596a313744c72c954a33c476fc7a` was read back from the Cloud Trace API.
It contained a `GET /` server span with:

- service name `gke-response-service`;
- service version `00f622a8c44579c662aa1387f1b9e5c35cba4f4e`;
- cluster `gke-primary`;
- region and zone `us-central1` and `us-central1-a`;
- platform `gcp_kubernetes_engine`;
- OpenTelemetry Go SDK version `1.47.0`.

The corresponding structured request log contained the Cloud Logging trace,
span, and sampled fields. This proves authenticated OTLP export through the
Telemetry API and log/trace correlation without a service-account key.

## Error Reporting

A bounded in-cluster request called `/error` with request ID
`response-error-reporting-001`. The service returned the intended HTTP 500 and
Cloud Logging retained both:

- the trace-correlated request-completion record; and
- a structured error event containing a Go stack trace plus service and
  immutable-version context.

Google Error Reporting assigned the stack event to group:

```text
CIPGhZW4v5DPiQE
```

No secret value was read or printed during this verification.

## Rollout troubleshooting and correction

The first observability upgrade failed before its container started and Helm
rolled back automatically. The failed manifest showed the numeric project
number rendered in scientific notation:

```text
projects/1.50538255871e+11/secrets/...
```

This produced an invalid Secret Manager CSI resource name. Response-service PR
11 normalizes the chart value through Helm `int64`, and the deployment command
also uses `--set-string`. The corrected dry run rendered:

```text
projects/150538255871/secrets/gke-sre-response-demo-token/versions/latest
```

The retry completed successfully. This incident demonstrates why rendered
manifests must be inspected when Helm values contain long numeric identifiers.

## Distributed-tracing follow-up

The response service was subsequently published as immutable image
`7aa78243c6cb864d7decfe80646ded3f0641c7fe` and deployed in both clusters. The
request service was instrumented and now propagates W3C trace context. A live
request in each region produced one trace containing the request-service server
span, its outbound client span, and this service's downstream server span.

The complete primary and secondary results are retained in
[distributed-tracing.md](distributed-tracing.md). A live Cloud Profiler sample
is the only remaining evidence in this observability group.
