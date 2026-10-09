# Distributed Tracing Evidence

**Verified:** October 9, 2026 (America/Chicago)  
**GCP project:** `gke-sre-assesment`  
**Namespace:** `assessment-apps`

## Purpose

This evidence proves that one request produces a single distributed trace
across both applications. Application A (`gke-request-info-service`) creates
the inbound server span and outbound HTTP client span. It propagates W3C trace
context to Application B (`gke-response-service`), which creates the downstream
server span.

Both applications use GKE Workload Identity and authenticated Google Cloud
Telemetry export. No service-account key is stored in either repository or
Kubernetes.

## Immutable releases

The same releases were deployed to both clusters:

| Application | Commit-derived image tag | Artifact Registry digest |
| --- | --- | --- |
| Request info | `03ea1316292d2c605b73b67d0eb28f31d775d0ee` | `sha256:45d638bf0d373c90691e3733ab1e22ab7ebac1facefec8220766c990743ba457` |
| Response | `7aa78243c6cb864d7decfe80646ded3f0641c7fe` | `sha256:ab5fc6d7e62fd50dccc91f2b12008d9ac1d287d7def775883980dc0fe6f0abd6` |

Each Deployment reached two of two available replicas with zero restarts. The
response Service had two ready endpoints in each cluster. The response release
retained the Secret Manager CSI integration and its secret-scoped Kubernetes
service account.

## Primary-cluster verification

An external request entered the existing primary GKE Ingress:

```text
Request ID: distributed-trace-verification-001
HTTP result: 200
Cluster: gke-primary
Region: us-central1
Trace ID: d926755352d34508e08f039b0b22f662
```

The response identified the new immutable versions at both hops. Structured
logs from both application pods contained the same request ID, Cloud Trace ID,
sampled flag, and their respective span IDs.

Reading the trace from the Cloud Trace API returned this parent-child graph:

```text
GET /                  request-info server span
└── HTTP GET           request-info outbound client span
    └── GET /          response-service server span
```

The client span's parent was the request-info server span, and the response
server span's parent was the client span. This proves propagation rather than
three unrelated spans.

## Secondary-cluster verification

A disposable curl pod called the request-info ClusterIP Service. This avoided
creating another public load balancer solely for evidence collection. The pod
was removed automatically after the request.

```text
Request ID: secondary-distributed-trace-001
HTTP result: 200
Cluster: gke-secondary
Region: us-east1
Trace ID: e4273926c3c58b569329ccf2f74f7c23
```

The returned payload showed Application A and Application B running in
`gke-secondary`, using the two immutable versions above. Cloud Logging retained
correlated completion records from both application pods. Both records had the
same sampled trace ID.

The Cloud Trace API returned the same three-span hierarchy:

```text
GET /                  request-info server span
└── HTTP GET           request-info outbound client span
    └── GET /          response-service server span
```

## Operational observation

The first primary request-info upgrade encountered a server-side apply
conflict on `metadata.annotations.cloud.google.com/neg`. GKE multi-cluster
configuration had expanded the annotation and recorded `Go-http-client` as its
field manager. Helm 4 correctly refused to overwrite that ownership silently.
The retry used `--force-conflicts`, which reconciled this known annotation
without replacing the Service or load balancer. Helm revision 7 then deployed
successfully.

The secondary request service has no standalone Ingress, so it did not have the
same annotation conflict.

## Reverification

Use a unique request ID, then correlate Cloud Logging by that value:

```bash
gcloud logging read \
  'jsonPayload.request_id="<request-id>" AND resource.type="k8s_container"' \
  --project=gke-sre-assesment \
  --freshness=15m \
  --format='json(timestamp,trace,spanId,traceSampled,resource.labels.cluster_name,resource.labels.pod_name,jsonPayload.message,jsonPayload.request_id)'
```

The corresponding trace can be inspected in Cloud Trace using the ID at the
end of the returned `trace` field.

## Remaining observability evidence

Distributed trace propagation is complete in both regions. The remaining item
for the combined Cloud Trace, Profiler, and Error Reporting requirement is a
retained live Cloud Profiler sample.
