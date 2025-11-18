# First 10 Commands — Quick Start (one page)

This file lists the first 10 commands to run when you begin working with the Phase 2 Kubernetes manifests in this repo. Run them in order, observe output, and use the notes to know what to expect.

1. Apply the namespace

```bash
kubectl apply -f kubernetes/00-namespace/namespace.yaml
```

- Purpose: create the `api-gateway-poc` namespace where all resources will live.
- Expect: `namespace/api-gateway-poc created` (or `configured`).

2. Apply ConfigMaps and Secrets

```bash
kubectl apply -f kubernetes/01-config/
```

- Purpose: create non-sensitive configuration (ConfigMaps) and DEV-only Secrets used by Keycloak.
- Expect: several `configmap/` and `secret/` objects created.

3. Create Redis PVC

```bash
kubectl apply -f kubernetes/02-storage/redis-pvc.yaml
kubectl get pvc -n api-gateway-poc
```

- Purpose: provision persistent storage for Redis. Verify PVC status is `Bound`.
- Expect: `redis-data` PVC shows `Bound` within a few seconds.

4. Deploy Redis

```bash
kubectl apply -f kubernetes/03-data/
kubectl wait --for=condition=available deployment/redis -n api-gateway-poc --timeout=120s
```

- Purpose: start Redis (data layer) before other services.
- Expect: `deployment.apps/redis created` then the `wait` returns when ready.

5. Deploy Keycloak

```bash
kubectl apply -f kubernetes/04-iam/
kubectl rollout status deployment/keycloak -n api-gateway-poc --watch
```

- Purpose: start Keycloak (IAM). Keycloak can take ~90s to become ready on first run.
- Expect: `deployment.apps/keycloak created` and eventually `deployment "keycloak" successfully rolled out`.

6. Deploy Authorization service

```bash
kubectl apply -f kubernetes/05-authz/
kubectl rollout status deployment/authz-service -n api-gateway-poc
```

- Purpose: start the external authz service that Envoy will call.
- Expect: pod enters `Running` and readiness probe passes.

7. Deploy backend services (customer & product)

```bash
kubectl apply -f kubernetes/06-services/
kubectl rollout status deployment/customer-service -n api-gateway-poc
kubectl rollout status deployment/product-service -n api-gateway-poc
```

- Purpose: bring up FastAPI services.
- Expect: both deployments report successful rollout.

8. Deploy Envoy gateway

```bash
kubectl apply -f kubernetes/07-envoy-gateway/
kubectl rollout status deployment/envoy -n api-gateway-poc
```

- Purpose: start Envoy (API gateway) using the ConfigMap `envoy-config`.
- Expect: envoy pod becomes `Running`; LoadBalancer service appears.

9. Check pods and services

```bash
kubectl get pods -n api-gateway-poc
kubectl get svc -n api-gateway-poc
```

- Purpose: quick verification that resources are present and services have endpoints.
- Expect: all pods reported; `envoy` and `keycloak` services show `EXTERNAL-IP` or accessible via `localhost` on Docker Desktop.

10. Test endpoints (basic)

```bash
# Envoy admin
curl http://localhost:9901/ready
# Keycloak health
curl http://localhost:8180/health/ready
# Product endpoint (no auth)
curl http://localhost:8080/products
```

- Purpose: validate routing, gateway, and IAM are reachable.
- Expect: 200 responses (or `401` for auth-protected endpoints if token not provided).

Quick tips

- To follow logs:
  - `kubectl logs -f deployment/keycloak -n api-gateway-poc`
  - `kubectl logs -f deployment/envoy -n api-gateway-poc`
- To port‑forward instead of using LoadBalancer:
  - `kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080`
  - `kubectl port-forward -n api-gateway-poc svc/keycloak 8180:8180`
- To restart a deployment after ConfigMap change:
  - `kubectl rollout restart deployment/authz-service -n api-gateway-poc`

End of first 10 commands — use these to get the cluster running and to start learning kubectl workflow.