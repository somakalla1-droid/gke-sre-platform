# Application Tracing, Profiling, and Error Reporting

## Objective

Add application-level observability without static credentials and preserve a
single distributed trace across Application A and Application B. The rollout
is separated into platform identity, application instrumentation, deployment,
and evidence so that each boundary can be reviewed and rolled back.

## Platform identity

The foundation enables:

- Cloud Trace API.
- Telemetry API for native OTLP trace ingestion.
- Cloud Profiler API.
- Error Reporting API.

Only the two application Kubernetes service accounts receive observability
writer roles:

| Kubernetes service account | Namespace | Roles |
| --- | --- | --- |
| `request-info-gke-request-info-service` | `assessment-apps` | `roles/cloudtrace.agent`, `roles/cloudprofiler.agent` |
| `response-service-workload` | `assessment-apps` | `roles/cloudtrace.agent`, `roles/cloudprofiler.agent` |

The IAM members use direct Workload Identity Federation for GKE principal
identifiers. No Google service-account key is created, and neither application
receives broader project permissions.

## Application design

The assessment implementation will:

1. Initialize an OpenTelemetry tracer provider with the standard OTLP gRPC
   exporter, Google Application Default Credentials, and the Google Cloud
   Telemetry API endpoint.
2. Add an HTTP server span around each inbound request.
3. Add an HTTP client span for Application A's call to Application B.
4. Propagate W3C `traceparent` and `tracestate` headers so both services appear
   in one distributed trace.
5. Attach service name, version, cluster, region, and pod attributes.
6. Start the supported Go Cloud Profiler agent with service and version labels.
7. Format controlled application errors as Error Reporting events in structured
   Cloud Logging while retaining the existing request-completion records.
8. Shut down the tracer provider gracefully so buffered spans are flushed
   during a rolling update.

The applications will remain functional when exporter initialization fails:
startup reports the observability error, but health and request handling do not
depend on an external telemetry backend.

## Ordered rollout

1. Merge and apply the platform API/IAM change.
2. Verify a drift-free foundation plan and the exact workload-principal roles.
3. Instrument and test the response service first.
4. Publish its commit-SHA image through the verified keyless CI pipeline.
5. Deploy it to the primary cluster and verify health.
6. Instrument, publish, and deploy the request service.
7. Send one correlated external request and verify a parent server span, an
   outbound client span, and the downstream server span in Cloud Trace.
8. Verify a controlled error group in Error Reporting and a live profile in
   Cloud Profiler when the service has accumulated enough samples.
9. Roll the same immutable images to the secondary cluster and repeat the
   cross-service verification.

## Assessment and production boundary

Google recommends OpenTelemetry with an OTLP exporter and collector for a
general production architecture. For this small assessment, authenticated OTLP
export directly to the Telemetry API is acceptable and reduces another
continuously running collector workload. A production design should centralize
sampling, retries, redaction, and multi-backend export in an OpenTelemetry
Collector.

References:

- [Instrument applications for Cloud Trace](https://cloud.google.com/trace/docs/setup)
- [Profile Go applications](https://cloud.google.com/profiler/docs/profiling-go)
- [Format Error Reporting events](https://cloud.google.com/error-reporting/docs/formatting-error-messages)
