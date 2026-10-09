# Horizontal Pod Autoscaler Scaling Evidence

**Verified:** October 9, 2026 (America/Chicago)
**Cluster:** `gke-primary` in `us-central1-a`
**Namespace:** `assessment-apps`

## Baseline

Both application deployments began with two ready replicas. Their HPAs used
CPU utilization with a 70% target and allowed between two and five replicas.
The request-service container requested `50m` CPU and was limited to `250m`.

```text
NAME                                    TARGETS      MINPODS   MAXPODS   REPLICAS
request-info-gke-request-info-service   cpu: 2%/70%  2         5         2
response-gke-response-service           cpu: 1%/70%  2         5         2
```

## Bounded load

A single temporary Fortio Pod ran inside the primary cluster for four minutes.
It sent traffic directly to Application A's ClusterIP Service so the test was
isolated from global load-balancer distribution. Each root request also called
Application B through internal Kubernetes DNS.

```bash
kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  run hpa-load-20261009 \
  --image=fortio/fortio:1.69.4 \
  --restart=Never \
  --labels=assessment.test=hpa-scaling \
  --command -- \
  fortio load -quiet -qps 0 -c 100 -t 4m \
  http://request-info-gke-request-info-service/
```

Fortio completed 185,313 measured requests at approximately 771 requests per
second with a 129.603 ms average response time:

```text
Code 200 : 185243 (100.0 %)
Code 502 : 70 (0.0 %)
All done 185313 calls (plus 100 warmup) 129.603 ms avg, 771.0 qps
```

The precise success rate was approximately 99.96%. The 70 transient 502
responses occurred during intentional saturation and scale-up. The normal
global request path returned HTTP 200 immediately after the load generator was
removed.

## Scale-up result

Both HPAs calculated five desired replicas and recorded CPU-based
`SuccessfulRescale` events:

| Workload | Peak observed CPU target | HPA events | Available result |
| --- | --- | --- | --- |
| Request service | `491%/70%` | New size 4, then 5 | Scaled from 2 to 3 available; 2 remained Pending |
| Response service | `214%/70%` | New size 3, then 5 | Scaled from 2 to 5 available |

The response-service scale-out demonstrates the full configured range. The
request-service HPA also selected five replicas, but the fixed three-node pool
could schedule only one additional request Pod. The scheduler reported:

```text
0/3 nodes are available: 3 Insufficient cpu.
```

This is an intentional assessment cost boundary, not an HPA-control failure.
Cluster autoscaling is disabled to prevent unbounded free-trial spending. In a
production design, node-pool autoscaling or additional reserved capacity must
be enabled so every HPA-selected replica can become available.

## Cleanup and service verification

The temporary generator was deleted after it completed:

```bash
kubectl \
  --context=gke_gke-sre-assesment_us-central1-a_gke-primary \
  --namespace=assessment-apps \
  delete pod hpa-load-20261009 --wait=true
```

Request `hpa-recovery-001` through the global Gateway returned HTTP 200 after
cleanup. Application A and Application B both ran in `gke-primary`, and both
hops preserved the request ID.

After the normal scale-down stabilization window, both HPAs recorded
`SuccessfulRescale` events with `New size: 2` because CPU utilization was below
target. Both deployments returned to their configured minimum of two replicas.
No application or infrastructure configuration was changed by this test.
