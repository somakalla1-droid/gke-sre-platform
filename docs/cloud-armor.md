# Cloud Armor WAF

## Purpose

The assessment's public multi-cluster application uses the global Cloud Armor
policy `gke-assessment-web-waf`. Terraform creates the policy independently of
the GKE Gateway so that the security control exists before the Gateway
controller provisions its backend service.

The initial policy contains two stable Google preconfigured WAF rules:

- SQL injection (`sqli-v33-stable`) is denied with HTTP 403 at priority 1000.
- Cross-site scripting (`xss-v33-stable`) is denied with HTTP 403 at priority
  1100.
- Requests not matching either WAF rule are allowed by the required default
  rule at priority 2147483647.

Rate limiting is intentionally deferred until after functional and failover
testing establishes a safe traffic baseline. An arbitrary low threshold could
invalidate the assessment's load and recovery evidence.

## Gateway attachment

The policy alone does not protect a backend. A `GCPBackendPolicy` in the
`assessment-apps` namespace attaches it to the generated
`request-info-gke-request-info-service` `ServiceImport`. For multi-cluster
Gateways, Google requires policies to target `ServiceImport`, not the
cluster-local `Service`.

Apply order:

1. Create and verify the Terraform-managed Cloud Armor policy.
2. Confirm both request-service `ServiceExport` resources are `Exported=True`.
3. Apply the `GCPBackendPolicy` in the primary config cluster.
4. Apply the global external multi-cluster `Gateway` and `HTTPRoute`.
5. Verify the policy is attached to the generated backend service and test a
   normal request plus a safe WAF test request.

The existing single-cluster Ingress remains the rollback endpoint until the
multi-cluster route, Cloud Armor attachment, and failover test all pass.

## Cost and cleanup

Cloud Armor policies, rules, and processed requests are billable. Retain this
policy only for the assessment evidence window. During final cleanup, delete
the `HTTPRoute`, `Gateway`, and `GCPBackendPolicy` before destroying the policy
with Terraform so the Gateway controller does not reference a missing policy.

## Reference

- [Configure Gateway resources using Policies](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-gateway-resources)
- [Cloud Armor preconfigured WAF rules](https://cloud.google.com/armor/docs/waf-rules)
