# Trusted HTTPS Gateway Evidence

**Verified:** October 11, 2026  
**Project:** `gke-sre-assesment`  
**Hostname:** `gke-sre-assessment.duckdns.org`  
**Terraform-owned global IP:** `8.232.146.143`

## Outcome

The global external multi-cluster Gateway provides browser-trusted HTTPS for
the assessment application. The cutover retained the existing multi-region
backend, internal Application A-to-B call, and Cloud Armor policy.

## DNS, certificate, and Gateway

Read-only verification returned:

- DuckDNS `A` record: `8.232.146.143`;
- Gateway address: `8.232.146.143`;
- Gateway conditions: `Scheduled=True`, `Accepted=True`, `Programmed=True`,
  `Ready=True`, and `GatewayHealthy=True`;
- Google-managed certificate status: `ACTIVE`;
- domain authorization status for `gke-sre-assessment.duckdns.org`: `ACTIVE`;
  and
- certificate expiry: January 9, 2027.

Terraform manages the global address and Google-managed certificate. The
Gateway and HTTPRoute are version controlled under
`kubernetes/multi-cluster-gateway/`.

## HTTPS application verification

A request to the hostname was made without `--insecure` or any certificate
bypass:

```bash
curl -i \
  -H 'X-Request-ID: pr54-final-verification' \
  https://gke-sre-assessment.duckdns.org/
```

Observed result: HTTP 200 from remote IP `8.232.146.143`. The previously
verified application response contains Application A and its nested
Application B response with the same propagated request ID.

## Cloud Armor regression over HTTPS

A harmless SQL-injection-shaped value was sent to an ignored query parameter:

```bash
curl -i \
  'https://gke-sre-assessment.duckdns.org/?q=%27%20OR%201%3D1--'
```

Observed result: HTTP 403. A normal HTTPS request immediately returned HTTP
200, distinguishing expected WAF enforcement from a TLS, Gateway, or backend
failure. No database query or destructive action was performed.

## Production disposition

DuckDNS was a no-cost authoritative hostname suitable for this assessment. A
production environment should replace it with an organization-owned domain
and Cloud DNS managed zone while retaining the stable address, managed
certificate lifecycle, Gateway health checks, and WAF verification process.
