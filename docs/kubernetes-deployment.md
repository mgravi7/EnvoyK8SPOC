# Kubernetes Deployment Guide

This guide covers deploying EnvoyK8SPOC to Kubernetes using Docker Desktop with both Phase 2 (direct Envoy) and Phase 3 (Gateway API) deployments.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Phase 2: Direct Envoy Deployment](#phase-2-direct-envoy-deployment)
  - [Quick Start Phase 2](#quick-start-phase-2)
  - [Detailed Deployment Steps Phase 2](#detailed-deployment-steps-phase-2)
- [Phase 3: Gateway API Deployment](#phase-3-gateway-api-deployment)
  - [Quick Start Phase 3](#quick-start-phase-3)
  - [Detailed Deployment Steps Phase 3](#detailed-deployment-steps-phase-3)
- [Verification](#verification)
- [Testing](#testing)
- [Accessing Services](#accessing-services)
- [Common Issues](#common-issues)
- [Clean Up](#clean-up)

## Prerequisites

### Required Software
- [x] Windows 11 or macOS
- [x] Docker Desktop with Kubernetes enabled
- [x] kubectl (installed with Docker Desktop)
- [x] Git
- [x] Python 3.12 (for running tests)

### Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Go to Settings (gear icon)
3. Click on "Kubernetes" in the left sidebar
4. Check "Enable Kubernetes"
5. Click "Apply & Restart"
6. Wait for Kubernetes to start (status indicator shows green)

### Verify Installation

```bash
# Check Docker
docker --version

# Check Kubernetes
kubectl version --client
kubectl cluster-info

# Check Python
python --version
```

Expected output:
- Docker: 20.10+ or newer
- Kubernetes: v1.25+ or newer
- Python: 3.12.x

---

## Phase 2: Direct Envoy Deployment

Phase 2 uses direct Envoy Proxy deployment with static configuration in ConfigMap.

### Quick Start Phase 2

**1. Build Images:**

```bash
# Linux/Mac/WSL
cd scripts/bash
chmod +x *.sh
./build-images.sh

# Windows PowerShell
cd scripts\powershell
.\build-images.ps1
```

**2. Deploy to Kubernetes:**

```bash
# Linux/Mac/WSL
./deploy-k8s-phase2.sh

# Windows PowerShell
.\deploy-k8s-phase2.ps1
```

**3. Verify and Test:**

```bash
# Linux/Mac/WSL
./verify-deployment.sh
./test-endpoints.sh

# Windows PowerShell
.\verify-deployment.ps1
.\test-endpoints.ps1
```

### Detailed Deployment Steps Phase 2

<details>
<summary>Click to expand Phase 2 detailed steps</summary>

#### Step 1: Build Docker Images

All services need to be built as Docker images before deploying to Kubernetes.

```bash
# From repository root
cd scripts/bash
./build-images.sh
```

This builds:
- customer-service:latest
- product-service:latest
- authz-service:latest
- keycloak:latest
- envoy:latest

Verify images:
```bash
docker images | grep -E "customer-service|product-service|authz-service|keycloak|envoy"
```

#### Step 2: Deploy Kubernetes Resources

Resources are deployed in this order:

1. **Namespace** (api-gateway-poc)
2. **ConfigMaps and Secrets**
3. **Storage** (Redis PVC)
4. **Redis** (wait for ready)
5. **Keycloak** (wait for ready - takes ~90 seconds)
6. **Authorization Service** (wait for ready)
7. **Backend Services** (customer-service, product-service)
8. **Envoy Gateway** (wait for ready)

Use the automated script:
```bash
./scripts/bash/deploy-k8s-phase2.sh
```

Or deploy manually:
```bash
kubectl apply -f kubernetes/00-namespace/
kubectl apply -f kubernetes/01-config/
kubectl apply -f kubernetes/02-storage/
kubectl apply -f kubernetes/03-data/
# Wait for Redis...
kubectl apply -f kubernetes/04-iam/
# Wait for Keycloak...
kubectl apply -f kubernetes/05-authz/
kubectl apply -f kubernetes/06-services/
kubectl apply -f kubernetes/07-envoy-gateway/
```

#### Step 3: Verify All Pods Are Running

```bash
kubectl get pods -n api-gateway-poc
```

Expected output (all pods should be Running):
```
NAME                               READY   STATUS    RESTARTS   AGE
authz-service-xxx                  1/1     Running   0          2m
customer-service-xxx               1/1     Running   0          2m
envoy-xxx                          1/1     Running   0          1m
keycloak-xxx                       1/1     Running   0          3m
product-service-xxx                1/1     Running   0          2m
redis-xxx                          1/1     Running   0          4m
```

</details>

---

## Phase 3: Gateway API Deployment

Phase 3 uses Kubernetes Gateway API with Envoy Gateway operator for declarative, Kubernetes-native configuration.

### Phase 3 Architecture

Phase 3 introduces a separation between the **control plane** (Envoy Gateway controller) and the **data plane** (Envoy proxy) using dedicated namespaces for better isolation and management.

```
┌──────────────────────────────────────────────────────────────────┐
│                 Envoy Gateway Architecture (Phase 3)             │
└──────────────────────────────────────────────────────────────────┘

Namespace: envoy-gateway-system
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  Control Plane:                                                │
│  └─ envoy-gateway (controller)                                 │
│     - Watches Gateway API resources                            │
│     - Generates Envoy configuration dynamically                │
│     - Manages data plane lifecycle                             │
│                                                                │
│  Data Plane:                                                   │
│  └─ envoy-api-gateway-poc-api-gateway-xxxxxx (proxy pod)       │
│     ├─ Envoy proxy containers (2/2 running)                    │
│     ├─ LoadBalancer Service (localhost:8080)                   │
│     └─ Automatically created & managed by Envoy Gateway        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
                           ▲
                           │ watches & manages
                           │
Namespace: api-gateway-poc
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  Gateway API Resources (declarative config):                   │
│  ├─ GatewayClass (envoy-gateway)                               │
│  ├─ Gateway (api-gateway) - defines listeners                  │
│  ├─ HTTPRoutes - define routing rules                          │
│  │  ├─ customer-route   → customer-service                     │
│  │  ├─ product-route    → product-service                      │
│  │  ├─ auth-me-route    → authz-service                        │
│  │  └─ keycloak-route   → keycloak                             │
│  └─ SecurityPolicies - define auth & security                  │
│     ├─ jwt-authentication (JWT validation)                     │
│     └─ external-authorization (RBAC checks)                    │
│                                                                │
│  Application Workloads (backend services):                     │
│  ├─ customer-service (Deployment + Service)                    │
│  ├─ product-service  (Deployment + Service)                    │
│  ├─ authz-service    (Deployment + Service)                    │
│  ├─ keycloak         (Deployment + LoadBalancer Service)       │
│  └─ redis            (Deployment + Service + PVC)              │
│                                                                │
└────────────────────────────────────────────────────────────────┘

Traffic Flow:
  Client Request → Gateway Service (envoy-gateway-system:8080)
                → Envoy Proxy (applies HTTPRoute rules + SecurityPolicies)
                → Backend Service (api-gateway-poc)
                → Response
```

**Key Benefits of This Architecture:**

1. **Separation of Concerns:**
   - Control plane manages configuration
   - Data plane handles traffic
   - Application workloads are isolated

2. **Dynamic Configuration:**
   - Changes to HTTPRoutes/SecurityPolicies are applied without pod restarts
   - Envoy Gateway automatically updates Envoy proxy configuration

3. **Namespace Isolation:**
   - `envoy-gateway-system`: Infrastructure components
   - `api-gateway-poc`: Application-specific resources

4. **Multi-Gateway Support:**
   - Single Envoy Gateway controller can manage multiple Gateways
   - Each Gateway gets its own Envoy proxy deployment

**Why Data Plane is in `envoy-gateway-system`:**

By default, Envoy Gateway deploys the data plane (Envoy proxy pods) in the same namespace as the control plane (`envoy-gateway-system`). This is intentional for:
- **Centralized management:** All infrastructure in one namespace
- **Security isolation:** Gateway operator has full control over proxy lifecycle
- **Multi-tenant support:** Multiple applications can have Gateways without namespace conflicts

**Note:** While the Envoy proxy pod runs in `envoy-gateway-system`, it is logically owned by the Gateway resource in `api-gateway-poc` and is visible via labels:
```bash
kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
```

### Quick Start Phase 3

**Prerequisites:**
- Helm 3.x installed (install via `winget install Helm.Helm` on Windows 11)

**1. Install Helm (if not already installed):**

```bash
# Windows 11 (recommended)
winget install Helm.Helm

# Or via Chocolatey
choco install kubernetes-helm

# Verify installation
helm version
```

**2. Clean up any existing Gateway API CRDs (if upgrading or reinstalling):**

```bash
# Delete existing Gateway API CRDs to avoid version conflicts
kubectl delete crd $(kubectl get crd -o name | Select-String "gateway") --ignore-not-found=true

# Verify clean slate
kubectl get crd | Select-String "gateway"
```

**3. Install Envoy Gateway v1.6.0 via Helm:**

```bash
# Install Envoy Gateway using Helm OCI registry
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.6.0 `
  --create-namespace `
  --namespace envoy-gateway-system

# Wait for Envoy Gateway to be ready
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify installation
kubectl get pods -n envoy-gateway-system
helm list -n envoy-gateway-system
```

**4. Build Images (if not already built):**

```bash
# Linux/Mac/WSL
cd scripts/bash
./build-images.sh

# Windows PowerShell
cd scripts\powershell
.\build-images.ps1
```

**5. Deploy Phase 3:**

```bash
# Linux/Mac/WSL
./deploy-k8s-phase3.sh

# Windows PowerShell
.\deploy-k8s-phase3.ps1
```

**6. Verify and Test:**

```bash
# Linux/Mac/WSL
./verify-deployment.sh
./test-endpoints.sh

# Windows PowerShell
.\verify-deployment.ps1
.\test-endpoints.ps1
```

### Notes & Clarifications
- **Helm vs kubectl:** Phase 3 now uses Helm for Envoy Gateway installation (v1.6.0) instead of kubectl apply. This avoids CRD size issues that occur with large manifests.
- **Version:** Using Envoy Gateway v1.6.0 (latest stable) instead of v1.2.0. Your existing manifests in `kubernetes/08-gateway-api/` should work with v1.6.0 as Gateway API v1 is stable.
- Tests: the test suite lives in `tests/` (unit + integration). Do not rely on a hardcoded count in docs — run `pytest -q` to see current totals.
- Keycloak token examples in this guide use the dev `test-client` (public) for convenience; for CI and automation use a confidential client with a secret or service account credentials.
- SecurityPolicy filenames and exact resources can vary; check `kubernetes/08-gateway-api/` for the authoritative file names. The migration scripts apply the JWT policy followed by the ext-auth policy used for public/no-JWT routes.
- Port mappings: see `docs/port-mappings.md` for an authoritative table of service → host mappings and notes about Docker Desktop behavior.
- Archived Phase summaries: legacy phase summaries moved to `docs/archive/`.

### Detailed Deployment Steps Phase 3

<details>
<summary>Click to expand Phase 3 detailed steps</summary>

#### Step 1: Install Envoy Gateway (One-time per cluster)

**Prerequisites:**
- Helm 3.x installed (install via `winget install Helm.Helm` on Windows 11)

**Option A: Install via Helm (Recommended for v1.6.0+)**

Helm handles large CRDs better than kubectl apply and avoids manifest size issues.

```bash
# 1. Install Helm if not already installed
# Windows 11
winget install Helm.Helm

# Or via Chocolatey
choco install kubernetes-helm

# Verify
helm version

# 2. Clean up any existing Gateway API CRDs (to avoid version conflicts)
kubectl delete crd $(kubectl get crd -o name | Select-String "gateway") --ignore-not-found=true

# 3. Install Envoy Gateway v1.6.0
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.6.0 `
  --create-namespace `
  --namespace envoy-gateway-system

# 4. Wait for Envoy Gateway to be ready
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# 5. Verify installation
kubectl get pods -n envoy-gateway-system
helm list -n envoy-gateway-system
kubectl get crd | grep gateway
```

**Option B: Install via kubectl (Alternative for v1.2.0)**

> **Note:** v1.6.0 manifests have CRD size issues with kubectl apply. Use Helm (Option A) for v1.6.0+.

```bash
# Install Envoy Gateway v1.2.0 (compatible with Envoy v1.31)
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml

# Wait for Envoy Gateway to be ready
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify installation
kubectl get pods -n envoy-gateway-system
kubectl get crd | grep gateway
```

Expected CRDs (both methods):
- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`
- `securitypolicies.gateway.envoyproxy.io`
- Plus additional Gateway API and Envoy Gateway CRDs

#### Step 2: Deploy Backend Services

Same as Phase 2 (steps 1-7), but skip the Envoy Deployment:

```bash
kubectl apply -f kubernetes/00-namespace/
kubectl apply -f kubernetes/01-config/
kubectl apply -f kubernetes/02-storage/
kubectl apply -f kubernetes/03-data/
kubectl apply -f kubernetes/04-iam/
kubectl apply -f kubernetes/05-authz/
kubectl apply -f kubernetes/06-services/
# Do NOT apply kubernetes/07-envoy-gateway/ in Phase 3
```

#### Step 3: Deploy Gateway API Resources

```bash
# GatewayClass
kubectl apply -f kubernetes/08-gateway-api/01-gatewayclass.yaml

# Gateway (this auto-creates Envoy proxy Deployment + Service)
kubectl apply -f kubernetes/08-gateway-api/02-gateway.yaml

# Wait for Gateway to be ready
kubectl wait --for=condition=programmed gateway/api-gateway -n api-gateway-poc --timeout=180s

# HTTPRoutes
kubectl apply -f kubernetes/08-gateway-api/03-httproute-customer.yaml
kubectl apply -f kubernetes/08-gateway-api/04-httproute-product.yaml
kubectl apply -f kubernetes/08-gateway-api/05-httproute-auth-me.yaml
kubectl apply -f kubernetes/08-gateway-api/06-httproute-keycloak.yaml

# SecurityPolicies
kubectl apply -f kubernetes/08-gateway-api/07-securitypolicy-jwt.yaml
kubectl apply -f kubernetes/08-gateway-api/08-securitypolicy-extauth.yaml
```

Or use the automated script:
```bash
./scripts/bash/deploy-k8s-phase3.sh
```

#### Step 4: Verify Gateway API Resources

```bash
# Check Gateway status
kubectl get gateway -n api-gateway-poc
kubectl describe gateway api-gateway -n api-gateway-poc

# Check HTTPRoutes
kubectl get httproute -n api-gateway-poc -o wide

# Check SecurityPolicies
kubectl get securitypolicy -n api-gateway-poc
kubectl get securitypolicy -n api-gateway-poc -o yaml  # view policy targets and mappings

# Check generated Envoy proxy
kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

# Check Gateway service
kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway -o wide
```

If you need to remove an existing SecurityPolicy while iterating on policy changes, delete it with:

```bash
# Delete a named SecurityPolicy
kubectl delete securitypolicy jwt-required-routes-securitypolicy -n api-gateway-poc

# Or delete all SecurityPolicies in the namespace (use with caution)
kubectl delete securitypolicy --all -n api-gateway-poc
```

After deleting, re-apply your updated policy YAML:

```bash
kubectl apply -f kubernetes/08-gateway-api/07-securitypolicy-jwt.yaml
kubectl apply -f kubernetes/08-gateway-api/09-securitypolicy-extauth-noJWT-routes.yaml
```

</details>

### Phase 3 vs Phase 2

| Feature | Phase 2 | Phase 3 |
|---------|---------|---------|
| **Configuration** | Static envoy.yaml | Kubernetes CRDs |
| **Gateway** | Manual Deployment | Auto-created by Gateway |
| **Routing** | Envoy route_config | HTTPRoute resources |
| **Security** | Envoy http_filters | SecurityPolicy resources |
| **Updates** | ConfigMap edit + restart | Apply CRD (no restart) |

**See [docs/gateway-api-migration.md](gateway-api-migration.md) for detailed Phase 3 migration guide.**

---

## Verification

Run the verification script to check all components:

```bash
# Bash
./scripts/bash/verify-deployment.sh

# PowerShell
.\scripts\powershell\verify-deployment.ps1
```

The script automatically detects which phase is deployed and checks:
- ✓ All pods running
- ✓ Services and endpoints
- ✓ ConfigMaps and secrets
- ✓ Phase 2: Envoy Deployment
- ✓ Phase 3: Gateway, HTTPRoutes, SecurityPolicies
- ✓ Recent logs from each service

### Manual Verification

**Check Pods:**
```bash
kubectl get pods -n api-gateway-poc
```

**Check Services:**
```bash
kubectl get svc -n api-gateway-poc
```

**Phase 2 - Check Envoy:**
```bash
kubectl logs -f deployment/envoy -n api-gateway-poc
```

**Phase 3 - Check Gateway:**
```bash
# Gateway status
kubectl describe gateway api-gateway -n api-gateway-poc

# Envoy proxy logs
kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
```

## Testing

### Get JWT Token from Keycloak

```bash
# Direct Keycloak (Phase 2) - Keycloak running on port 8180 inside the cluster
curl -s -X POST "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" | jq -r '.access_token'
```

```bash
# Keycloak via Gateway (Phase 3) - Keycloak exposed by the Gateway under /auth
curl -s -X POST "http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" | jq -r '.access_token'
```

- For CI/automation prefer the confidential client (with client secret) or a service account flow; do not embed dev client secrets in public pipelines.

### Test Endpoints

**Public endpoint (no auth):**
```bash
curl http://localhost:8080/products
```

**Protected endpoints (requires JWT):**
```bash
# Customer service
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/customers

# Product service
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/products

# User info
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/auth/me
```

### Run Integration Tests

```bash
# Ensure GATEWAY_BASE_URL is set correctly in tests/integration/conftest.py
cd tests/integration
pytest -v
```

Expected: All 90 tests should pass (same for Phase 2 and Phase 3).

## Accessing Services

### Keycloak Admin Console
- URL: http://localhost:8180 (Phase 2) or http://localhost:8080/auth (Phase 3)
- Username: `admin`
- Password: `admin`

**WARNING: Development credentials only - DO NOT use in production**

### API Gateway
- **Phase 2:** http://localhost:8080 (Envoy direct)
- **Phase 3:** http://localhost:8080 (Gateway API)
- Admin: http://localhost:9901 (Phase 2 only)

### Available Endpoints

**Public (no auth):**
- GET http://localhost:8080/products
- GET http://localhost:8080/products/{id}
- GET http://localhost:8080/products/health

**Authenticated (JWT required):**
- GET http://localhost:8080/customers
- GET http://localhost:8080/customers/{id}
- GET http://localhost:8080/customers/health
- GET http://localhost:8080/auth/me

**Keycloak:**
- Token endpoint: http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token

## Common Issues

### Pods Not Starting

**Symptom:** Pods stuck in Pending, CrashLoopBackOff, or ImagePullBackOff

**Solutions:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n api-gateway-poc

# Check logs
kubectl logs <pod-name> -n api-gateway-poc

# Common causes:
# 1. Image not built - run ./build-images.sh
# 2. Insufficient resources - increase Docker Desktop memory (Settings > Resources)
# 3. Port conflicts - ensure ports 8080, 8180, 9901 are free
```

### LoadBalancer Stuck in Pending

**Symptom:** Service EXTERNAL-IP shows `<pending>`

**Solutions:**
```bash
# Docker Desktop should auto-assign localhost
# Wait a minute and check again
kubectl get svc -n api-gateway-poc

# If still pending, restart Docker Desktop
# Or use port-forward:
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080  # Phase 2
# Phase 3 - find the Gateway service name first:
kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
kubectl port-forward -n api-gateway-poc svc/<gateway-service-name> 8080:8080
```

### Phase 3: Gateway Not Ready

**Symptom:** Gateway status shows `Programmed: False`

**Solutions:**
```bash
# Check Gateway status and events
kubectl describe gateway api-gateway -n api-gateway-poc

# Check Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway --tail=50

# Verify Envoy Gateway is installed
kubectl get pods -n envoy-gateway-system

# Check for port conflicts with Phase 2
kubectl get deployment envoy -n api-gateway-poc
# If found, delete Phase 2 Envoy:
kubectl delete -f kubernetes/07-envoy-gateway/
```

### Phase 2 and Phase 3 Port Conflicts

**Symptom:** Cannot deploy Phase 3 while Phase 2 is running (or vice versa)

**Solutions:**
```bash
# Both phases use port 8080, so they cannot run simultaneously
# Option 1: Clean up and redeploy
./scripts/bash/cleanup-k8s.sh
./scripts/bash/deploy-k8s-phase3.sh  # or deploy-k8s-phase2.sh

# Option 2: Just delete the conflicting gateway
# For Phase 2 to Phase 3:
kubectl delete -f kubernetes/07-envoy-gateway/
# For Phase 3 to Phase 2:
kubectl delete gateway api-gateway -n api-gateway-poc
kubectl delete httproute --all -n api-gateway-poc
kubectl delete securitypolicy --all -n api-gateway-poc
```

### Keycloak Takes Long to Start

**Symptom:** Keycloak pod running but not ready

**Solutions:**
```bash
# Keycloak takes 90-120 seconds on first start
# Check logs for progress
kubectl logs -f deployment/keycloak -n api-gateway-poc

# Wait for: "Keycloak ... started in ..."
```

### Redis Connection Errors

**Symptom:** authz-service logs show Redis connection errors

**Solutions:**
```bash
# Verify Redis is running
kubectl get pods -n api-gateway-poc | grep redis

# Check Redis service
kubectl get svc redis -n api-gateway-poc

# Restart authz-service
kubectl rollout restart deployment/authz-service -n api-gateway-poc
```

### Tests Failing

**Symptom:** Integration tests fail after deployment

**Solutions:**
```bash
# 1. Verify GATEWAY_BASE_URL is correct
# Edit tests/integration/conftest.py:
# GATEWAY_BASE_URL = "http://localhost:8080"

# 2. Wait for all pods to be ready
kubectl get pods -n api-gateway-poc

# 3. Test manually first
curl http://localhost:8080/products

# 4. Get fresh token
TOKEN=$(curl -s -X POST "http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token" ...)

# 5. Run specific test
pytest tests/integration/test_customer_service.py -v
```

## Clean Up

To remove all deployed resources:

```bash
# Bash
./scripts/bash/cleanup-k8s.sh

# PowerShell
.\scripts\powershell\cleanup-k8s.ps1
```

This deletes:
- The entire `api-gateway-poc` namespace
- All Phase 2 and Phase 3 resources
- GatewayClass (Phase 3)

**Note:** Envoy Gateway operator (envoy-gateway-system namespace) is NOT deleted and can be reused.

### Uninstall Envoy Gateway

**If installed via Helm (recommended):**

```bash
# Uninstall Envoy Gateway
helm uninstall envoy-gateway -n envoy-gateway-system

# Delete the namespace
kubectl delete namespace envoy-gateway-system

# Clean up Gateway API CRDs (optional - only if you want a complete removal)
kubectl delete crd $(kubectl get crd -o name | Select-String "gateway")
```

**If installed via kubectl:**

```bash
# Uninstall using the install manifest
kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml

# Or delete the namespace directly
kubectl delete namespace envoy-gateway-system
```

## Next Steps

### After Phase 2
1. Review Kubernetes fundamentals
2. Understand service-to-service communication
3. Explore kubectl debugging commands
4. Prepare for Phase 3 migration

### After Phase 3
1. Review Gateway API concepts
2. Explore dynamic route updates
3. Consider Phase 4 enhancements (rate limiting, observability)
4. Plan production readiness improvements

## Reference

- **Project Plan:** `project-plan.md`
- **Phase 3 Migration Guide:** `docs/gateway-api-migration.md`
- **Gateway API Resources:** `kubernetes/08-gateway-api/README.md`
- **Troubleshooting:** `docs/troubleshooting.md`
- **Kubernetes Manifests:** `kubernetes/`
- **Deployment Scripts:** `scripts/`

## Issuer vs JWKS (dev vs prod)

When configuring JWT validation in SecurityPolicy you will often need two related but different URLs:

- `issuer` — the public URL that appears in the token `iss` claim and that clients use to talk to the identity provider (Keycloak).
- `remoteJWKS` — the internal URL where the data plane (Envoy) fetches the JWKS (public keys) to verify token signatures.

Why they can differ
- In local development the issuer is typically `http://localhost:8180/...` because developers and browsers access Keycloak on localhost.
- Envoy runs inside the Kubernetes cluster and needs a cluster-reachable hostname (for example `http://keycloak.api-gateway-poc.svc.cluster.local:8180/...`) to fetch the JWKS. Using the cluster DNS name ensures Envoy can resolve and connect to Keycloak from inside the cluster.

Recommendations
- Development (local):
  - Use `issuer` = `http://localhost:8180/...` so tokens contain the expected public issuer for local clients.
  - Use `remoteJWKS` = internal cluster URL (service DNS) so Envoy can fetch keys from inside the cluster.
  - Add a deploy-time check that Keycloak endpoints are ready before applying SecurityPolicies (this project does that in the deploy script to avoid JWKS fetch races).

- Production (cloud):
  - Use HTTPS for both `issuer` and `remoteJWKS` and a stable public hostname for the issuer (for example `https://auth.example.com/realms/...`).
  - Ensure Envoy can reach the JWKS URI. Often the public issuer URL is reachable internally as well (or use an internal hostname that resolves to Keycloak).
  - Validate that the `issuer` string in the SecurityPolicy exactly matches the `iss` claim in tokens.

Security notes
- Always prefer HTTPS for production JWKS/issuer endpoints.
- Ensure the JWKS endpoint is reachable from the Envoy proxy (data plane) and that the Keycloak service is ready before security policies are applied.
- Avoid exposing admin ports (like Envoy `9901`) publicly; use port-forwarding or a restricted management network for debugging.
