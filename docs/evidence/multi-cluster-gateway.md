# Multi-Cluster Gateway, Cloud Armor, and Failover Evidence

**Verified:** October 9, 2026  
**Project:** `gke-sre-assesment`  
**Config cluster:** `gke-primary` (`us-central1-a`)  
**Secondary cluster:** `gke-secondary` (`us-east1-b`)  
**Gateway address:** `136.81.84.189`

## Deployed control plane

The Fleet ingress feature reported `ACTIVE` and `Ready to use`; both regional
membership states reported `OK`. The primary config cluster exposed all five
accepted multi-cluster GatewayClasses. The deployed routing resources are:

- `Gateway/assessment-apps/request-info-global` using
  `gke-l7-global-external-managed-mc`.
- `HTTPRoute/assessment-apps/request-info-global` routing `/` to
  `ServiceImport/assessment-apps/request-info-gke-request-info-service`.
- `GCPBackendPolicy/assessment-apps/request-info-cloud-armor` attaching
  `gke-assessment-web-waf` to the imported backend.

The Gateway reported one attached route and address `136.81.84.189`. The route
reported `ResolvedRefs=True`, `Accepted=True`, and
`ReconciliationSucceeded=True`. The backend policy reported `Attached=True`.

## Multi-cluster backend health

Both Helm releases exported the same request-service name and namespace. Each
`ServiceExport` reported `Initialized=True` and `Exported=True`, and MCS created
the shared `ServiceImport` in both clusters.

Google Cloud backend health reported four healthy Pod endpoints:

| Cluster | Region/zone | Healthy Pod IPs | Port |
| --- | --- | --- | --- |
| `gke-primary` | `us-central1-a` | `10.20.1.14`, `10.20.2.11` | 8080 |
| `gke-secondary` | `us-east1-b` | `10.50.0.8`, `10.50.1.9` | 8080 |

## Normal request

After global URL-map propagation completed, this request returned HTTP 200:

```bash
curl -i \
  -H 'X-Request-ID: multi-cluster-gateway-002' \
  http://136.81.84.189/
```

The response showed:

- Application A: `gke-request-info-service` in `gke-primary`, `us-central1`.
- Application B: `gke-response-service` in `gke-primary`, `us-central1`.
- Correlation ID: `multi-cluster-gateway-002` at both hops.
- Downstream status: HTTP 200.

The first request during edge propagation returned the controller's temporary
`fault filter abort` 404. No configuration was reapplied. Once the URL map and
application backend propagated, the same endpoint returned HTTP 200. This is
normal asynchronous global load-balancer provisioning, not an application
failure.

## Cloud Armor enforcement

The global backend service referenced
`gke-assessment-web-waf`. A harmless encoded SQL-injection signature sent to an
ignored query parameter was blocked at the edge:

```bash
curl -i \
  -H 'X-Request-ID: cloud-armor-sqli-test-001' \
  'http://136.81.84.189/?q=%27%20OR%201%3D1--'
```

Observed result: `HTTP/1.1 403 Forbidden`. A normal request immediately before
the test returned HTTP 200, distinguishing WAF enforcement from backend
unavailability.

## Controlled regional failover

The primary request Service was withdrawn without stopping Pods or nodes by
temporarily adding a selector not present on any Pod:

```bash
kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  patch service request-info-gke-request-info-service \
  --type=merge \
  -p '{"spec":{"selector":{"assessment.failover/disabled":"true"}}}'
```

The primary EndpointSlice became empty. Google Cloud backend health then showed
no primary endpoints and two healthy secondary endpoints. The following
request still returned HTTP 200:

```bash
curl -i \
  -H 'X-Request-ID: multi-cluster-failover-001' \
  http://136.81.84.189/
```

The response proved regional failover and dependency locality:

- Application A ran in `gke-secondary`, `us-east1`.
- Application B ran in `gke-secondary`, `us-east1`.
- Both hops preserved `multi-cluster-failover-001`.

## Recovery

The temporary selector was removed immediately after the failover request:

```bash
kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  patch service request-info-gke-request-info-service \
  --type=merge \
  -p '{"spec":{"selector":{"assessment.failover/disabled":null}}}'
```

The original two-label selector and both primary endpoints returned. Backend
health again showed two healthy endpoints in each region. Request
`multi-cluster-recovery-001` returned HTTP 200 from the primary request and
response services.

## Safety and remaining work

The previous single-cluster Ingress at `136.81.197.123` remains available as a
rollback endpoint. The new Gateway is HTTP-only. DNS ownership, a certificate,
and HTTPS edge termination remain required before claiming the assignment's
HTTPS flow is complete.
