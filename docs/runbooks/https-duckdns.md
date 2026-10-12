# HTTPS and DuckDNS Cutover Runbook

## Purpose

This runbook converts the existing public multi-cluster HTTP endpoint to a
stable, browser-trusted HTTPS endpoint at
`https://gke-sre-assessment.duckdns.org`.

The change has four controlled phases. Terraform is applied first, Kubernetes
is changed second, DuckDNS is updated third, and HTTPS is accepted only after
the certificate and application are verified. The current HTTP listener is
retained as a rollback path.

## Preconditions

- The HTTPS pull request is merged to `main`.
- `gcloud`, Terraform, and `kubectl` are authenticated for
  `gke-sre-assesment`.
- The primary config-cluster context exists locally.
- The DuckDNS dashboard is accessible to the assessment owner.
- Do not copy the DuckDNS token into a terminal or repository.

## 1. Synchronize and validate

```bash
cd /Users/somakalla/Documents/ChatGPT/GKE-SRE
git switch main
git pull --ff-only
terraform -chdir=terraform/environments/assessment/foundation init -reconfigure
terraform -chdir=terraform/environments/assessment/foundation validate
kubectl kustomize kubernetes/multi-cluster-gateway >/dev/null
```

## 2. Plan and apply the Google Cloud resources

```bash
terraform -chdir=terraform/environments/assessment/foundation plan -out=https-duckdns.tfplan
terraform -chdir=terraform/environments/assessment/foundation apply https-duckdns.tfplan
```

The plan should add the global address and managed certificate. Review any
other proposed action before applying it.

Capture the assigned address and confirm both resources:

```bash
STATIC_IP=$(terraform -chdir=terraform/environments/assessment/foundation output -raw gateway_static_ip_address)
echo "$STATIC_IP"
gcloud compute addresses describe gke-sre-assessment-gateway-ip --global --project=gke-sre-assesment --format='yaml(name,address,status)'
gcloud compute ssl-certificates describe gke-sre-assessment-gateway-cert --global --project=gke-sre-assesment --format='yaml(name,managed.domains,managed.status)'
```

`PROVISIONING` is expected for the certificate at this point.

## 3. Move the Gateway to the named address and enable HTTPS

```bash
kubectl --context gke_gke-sre-assesment_us-central1-a_gke-primary apply -k kubernetes/multi-cluster-gateway
kubectl --context gke_gke-sre-assesment_us-central1-a_gke-primary --namespace assessment-apps wait --for=condition=Programmed gateway/request-info-global --timeout=20m
kubectl --context gke_gke-sre-assesment_us-central1-a_gke-primary --namespace assessment-apps get gateway/request-info-global httproute/request-info-global
```

Confirm the reported Gateway address equals `$STATIC_IP`. Before changing DNS,
verify that plain HTTP reaches the application on the new address:

```bash
curl -i -H 'Host: gke-sre-assessment.duckdns.org' -H 'X-Request-ID: https-cutover-http-001' "http://${STATIC_IP}/"
```

Do not update DNS unless this returns HTTP 200.

## 4. Update and verify DuckDNS

In the DuckDNS dashboard, replace the address for `gke-sre-assessment` with the
value printed in `$STATIC_IP`, then select **update ip**. Do not expose or copy
the account token.

```bash
dig +short A gke-sre-assessment.duckdns.org
```

Continue only when the result exactly matches `$STATIC_IP`.

## 5. Wait for the managed certificate

Certificate activation can take several minutes and occasionally longer. This
command is read-only and can be repeated:

```bash
gcloud compute ssl-certificates describe gke-sre-assessment-gateway-cert --global --project=gke-sre-assesment --format='yaml(managed.status,managed.domainStatus,expireTime)'
```

Continue when `managed.status` is `ACTIVE` and the hostname's domain status is
`ACTIVE`.

## 6. Verify HTTPS end to end

```bash
curl -i -H 'X-Request-ID: https-cutover-001' https://gke-sre-assessment.duckdns.org/
```

Acceptance criteria:

- TLS validation succeeds without `-k` or a browser exception.
- The HTTP status is `200`.
- The response identifies Application A and contains Application B's nested
  response.
- The request ID is present at both application hops.

Inspect the certificate independently:

```bash
openssl s_client -connect gke-sre-assessment.duckdns.org:443 -servername gke-sre-assessment.duckdns.org </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

## 7. Cloud Armor regression check

```bash
curl -i 'https://gke-sre-assessment.duckdns.org/?q=%27%20OR%201%3D1--'
```

The safe SQL-injection-shaped request should return HTTP 403, demonstrating
that TLS termination did not bypass the existing backend security policy.

## Rollback

If the HTTPS listener fails while the Gateway remains otherwise healthy, keep
DuckDNS pointed to the Terraform-owned static address `8.232.146.143` and use
the retained HTTP listener as the temporary recovery path. Revert only the
listener or certificate change through a reviewed manifest update. Do not
point DNS back to the earlier controller-owned address: its lifecycle is not
owned by Terraform and it is not a durable rollback target.

Do not destroy the Terraform-managed address or certificate during incident
recovery; retain them for diagnosis and a corrected retry. Resource deletion
belongs to the dependency-ordered assessment cleanup procedure after evidence
handoff.

If HTTP on the new static IP succeeds but the certificate remains
`PROVISIONING`, keep the Gateway and DNS in place and inspect `domainStatus`.
Certificate provisioning depends on public DNS resolving the hostname to the
load balancer using that certificate.
