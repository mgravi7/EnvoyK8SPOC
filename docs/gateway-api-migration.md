# Gateway API Migration Guide - Phase 3

**Status:** Ready for deployment

This document covers the migration from direct Envoy deployment (Phase 2) to Kubernetes Gateway API with Envoy Gateway (Phase 3).

## Overview

Phase 3 replaces the direct Envoy Proxy deployment with Kubernetes Gateway API resources, providing:
- **Declarative Configuration**: All routing and security via Kubernetes CRDs
- **Dynamic Updates**: Change routes without pod restarts
- **Standard API**: Portable across gateway implementations (can switch from Envoy to other implementations)
- **Better Integration**: Native Kubernetes resource management with kubectl

## Architecture Comparison

### Phase 2: Direct Envoy
```
Envoy Deployment (manual)
├── ConfigMap (envoy.yaml - static config)
├── Service (LoadBalancer)
└── Manual updates require pod restart
```

### Phase 3: Gateway API
```
Gateway (api-gateway)
├── Managed by Envoy Gateway Operator
├── Auto-creates Deployment, Service, ConfigMap
├── HTTPRoutes (dynamic routing rules)
├── SecurityPolicies (JWT + ext_authz)
└── Updates applied dynamically, no restart
```

## Prerequisites

Before starting Phase 3, ensure:
- ✅ Phase 2 is working successfully
- ✅ All 90 tests passing
- ✅ Understanding of current Envoy configuration
- ✅ Familiarity with kubectl and Kubernetes concepts
- ✅ Docker Desktop Kubernetes enabled

## Installation Steps

### Step 1: Install Envoy Gateway (One-time per cluster)

```bash
# Install Envoy Gateway v1.2.0 (compatible with Envoy v1.31)
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml

# Wait for Envoy Gateway to be ready
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify installation
kubectl get pods -n envoy-gateway-system
kubectl get crd | grep gateway
```

**Expected CRDs:**
- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`
- `referencegrants.gateway.networking.k8s.io`
- `securitypolicies.gateway.envoyproxy.io` (Envoy Gateway specific)

### Step 2: Deploy Phase 3 Resources

**Using deployment scripts (recommended):**

```bash
# Bash (Linux/Mac/WSL)
./scripts/bash/deploy-k8s-phase3.sh

# PowerShell (Windows)
.\scripts\powershell\deploy-k8s-phase3.ps1
```

The script will:
1. Check if Envoy Gateway is installed
2. Detect and optionally remove Phase 2 Envoy resources (port conflict prevention)
3. Deploy all backend services (if not already deployed)
4. Create Gateway API resources (GatewayClass, Gateway, HTTPRoutes, SecurityPolicies)
5. Wait for Gateway to be ready
6. Display status and next steps

**Manual deployment (if needed):**

```bash
# 1. Deploy backend services (if not already deployed)
./scripts/bash/deploy-k8s-phase2.sh  # But skip Envoy deployment

# 2. Create Gateway API resources
kubectl apply -f kubernetes/08-gateway-api/01-gatewayclass.yaml
kubectl apply -f kubernetes/08-gateway-api/02-gateway.yaml
kubectl apply -f kubernetes/08-gateway-api/03-httproute-customer.yaml
kubectl apply -f kubernetes/08-gateway-api/04-httproute-product.yaml
kubectl apply -f kubernetes/08-gateway-api/05-httproute-auth-me.yaml
kubectl apply -f kubernetes/08-gateway-api/06-httproute-keycloak.yaml
kubectl apply -f kubernetes/08-gateway-api/07-securitypolicy-jwt.yaml
kubectl apply -f kubernetes/08-gateway-api/08-securitypolicy-extauth.yaml
```

### Step 3: Verify Deployment

```bash
# Check Gateway status
kubectl get gateway -n api-gateway-poc
kubectl describe gateway api-gateway -n api-gateway-poc

# Check HTTPRoutes
kubectl get httproute -n api-gateway-poc

# Check SecurityPolicies
kubectl get securitypolicy -n api-gateway-poc

# Check generated Envoy proxy pods
kubectl get pods -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

# Check Gateway service (LoadBalancer)
kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

# Run verification script
./scripts/bash/verify-deployment.sh  # or verify-deployment.ps1 on Windows
```

**Expected output:**
- Gateway status: `Programmed: True`
- HTTPRoutes: 4 routes (customer, product, auth-me, keycloak)
- SecurityPolicies: 2 policies (JWT, ext_authz)
- Envoy proxy pod: Running
- LoadBalancer service: Assigned (localhost on Docker Desktop)

## Migration Details

### 1. GatewayClass

Defines which gateway controller to use:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
```

### 2. Gateway

Replaces Phase 2 Envoy Deployment:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: api-gateway
  namespace: api-gateway-poc
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: http
    protocol: HTTP
    port: 8080
```

Envoy Gateway automatically creates:
- Deployment (with Envoy proxy)
- Service (LoadBalancer type by default)
- ConfigMap (generated from Gateway API resources)

### 3. HTTPRoutes

Replace Phase 2 Envoy route_config:

**Phase 2 (envoy.yaml):**
```yaml
routes:
- match:
    prefix: "/customers"
  route:
    cluster: customer_service
```

**Phase 3 (HTTPRoute):**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: customer-route
spec:
  parentRefs:
  - name: api-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /customers
    backendRefs:
    - name: customer-service
      port: 8000
```

### 4. SecurityPolicies

Replace Phase 2 Envoy http_filters:

**Phase 2 (envoy.yaml):**
```yaml
http_filters:
- name: envoy.filters.http.jwt_authn
  typed_config:
    providers:
      keycloak_provider:
        issuer: http://localhost:8180/realms/api-gateway-poc
        remote_jwks:
          http_uri:
            uri: http://keycloak:8180/realms/...
```

**Phase 3 (SecurityPolicy):**
```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: jwt-authentication
spec:
  targetRef:
    kind: Gateway
    name: api-gateway
  jwt:
    providers:
    - name: keycloak-provider
      issuer: http://localhost:8180/realms/api-gateway-poc
      remoteJWKS:
        uri: http://keycloak.api-gateway-poc.svc.cluster.local:8180/realms/...
```

## Testing Phase 3

### 1. Basic Connectivity

```bash
# Get Gateway service (should be localhost on Docker Desktop)
kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

# Test Keycloak route (no auth required)
curl http://localhost:8080/auth/realms/api-gateway-poc
```

### 2. Authentication Flow

```bash
# Get JWT token from Keycloak
TOKEN=$(curl -X POST http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token \
  -d "client_id=customer-client" \
  -d "client_secret=customer-secret-key" \
  -d "username=alice@example.com" \
  -d "password=alice123" \
  -d "grant_type=password" | jq -r '.access_token')

echo "Token: $TOKEN"
```

### 3. Test Protected Endpoints

```bash
# Test customer service (requires JWT + customer-viewer role)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/customers

# Test product service (requires JWT + product-viewer role)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/products

# Test user info endpoint
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/auth/me
```

### 4. Run Full Test Suite

```bash
# Update test configuration if needed (should work with same localhost:8080)
cd tests
pytest integration/ -v
```

Expected: All 90 tests should pass (same as Phase 2)

## Key Differences from Phase 2

| Feature | Phase 2 | Phase 3 |
|---------|---------|---------|
| **Configuration Format** | Static envoy.yaml | Kubernetes CRDs |
| **Gateway Deployment** | Manual Deployment YAML | Auto-created by Gateway |
| **Routing** | Envoy route_config | HTTPRoute resources |
| **Security** | Envoy http_filters | SecurityPolicy resources |
| **Updates** | Edit ConfigMap + restart pod | Apply CRD changes (dynamic) |
| **Management** | kubectl + YAML editing | kubectl only |
| **Portability** | Envoy-specific | Standard Gateway API |
| **Observability** | Manual Envoy admin | Gateway API status fields |

## Benefits of Phase 3

1. **Declarative and Kubernetes-Native**
   - All configuration via kubectl
   - Consistent with other K8s resources
   - GitOps-friendly

2. **Dynamic Updates**
   - Add/modify routes without pod restart
   - Zero-downtime configuration changes
   - Faster iteration during development

3. **Standard API**
   - Portable across gateway implementations
   - Can switch from Envoy to other gateways
   - Community-driven specification

4. **Better Separation of Concerns**
   - Platform team manages Gateway/GatewayClass
   - App teams manage HTTPRoutes
   - Security team manages SecurityPolicies

5. **Enhanced Observability**
   - Gateway API status conditions
   - Better error reporting
   - Integrated with Kubernetes events

## Troubleshooting

### Gateway Not Ready

**Symptom:** Gateway status shows `Programmed: False`

```bash
# Check Gateway status
kubectl describe gateway api-gateway -n api-gateway-poc

# Check Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway --tail=50

# Check for events
kubectl get events -n api-gateway-poc --sort-by='.lastTimestamp'
```

**Common causes:**
- GatewayClass not found
- Invalid listener configuration
- Port conflicts with Phase 2 Envoy

### HTTPRoute Not Working

**Symptom:** Routes return 404 or not routing correctly

```bash
# Check HTTPRoute status
kubectl describe httproute customer-route -n api-gateway-poc

# Verify backend service exists and has endpoints
kubectl get svc customer-service -n api-gateway-poc
kubectl get endpoints customer-service -n api-gateway-poc

# Check Envoy proxy logs
kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
```

**Common causes:**
- Backend service doesn't exist
- Service selector doesn't match pods
- Path prefix mismatch
- Wrong namespace reference

### JWT Validation Failing

**Symptom:** Requests return 401 Unauthorized

```bash
# Check SecurityPolicy status
kubectl describe securitypolicy jwt-authentication -n api-gateway-poc

# Verify Keycloak JWKS endpoint is accessible
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc \
  -- curl http://keycloak.api-gateway-poc.svc.cluster.local:8180/realms/api-gateway-poc/protocol/openid-connect/certs

# Check Envoy proxy logs for JWT errors
kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway | grep -i jwt
```

**Common causes:**
- Keycloak not ready
- JWKS URL incorrect
- Token expired
- Issuer mismatch

### External Authorization Failing

**Symptom:** Requests return 403 Forbidden or authz errors

```bash
# Check SecurityPolicy status
kubectl describe securitypolicy external-authorization -n api-gateway-poc

# Verify authz-service is accessible
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc \
  -- curl http://authz-service.api-gateway-poc.svc.cluster.local:9000/authz/health

# Check authz-service logs
kubectl logs -n api-gateway-poc deployment/authz-service --tail=50

# Check Envoy proxy logs for ext_authz errors
kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway | grep -i authz
```

**Common causes:**
- authz-service not ready
- Redis not accessible
- User doesn't have required role
- Headers not forwarded correctly

### Port Conflicts with Phase 2

**Symptom:** Gateway service pending or Phase 2 Envoy still running

```bash
# Check if Phase 2 Envoy is still running
kubectl get deployment envoy -n api-gateway-poc

# Delete Phase 2 Envoy resources
kubectl delete -f kubernetes/07-envoy-gateway/

# Or use cleanup and redeploy
./scripts/bash/cleanup-k8s.sh
./scripts/bash/deploy-k8s-phase3.sh
```

## Rollback to Phase 2

If you need to rollback to Phase 2:

```bash
# 1. Delete Phase 3 resources
kubectl delete securitypolicy --all -n api-gateway-poc
kubectl delete httproute --all -n api-gateway-poc
kubectl delete gateway --all -n api-gateway-poc

# 2. Deploy Phase 2 Envoy
kubectl apply -f kubernetes/07-envoy-gateway/

# 3. Verify
./scripts/bash/verify-deployment.sh
```

Or use the deployment scripts:

```bash
# Full cleanup and redeploy Phase 2
./scripts/bash/cleanup-k8s.sh
./scripts/bash/deploy-k8s-phase2.sh
```

## Phase 2 vs Phase 3 Files

### Phase 2 Files (Keep for reference)
- `kubernetes/07-envoy-gateway/envoy-configmap.yaml` - Static Envoy config
- `kubernetes/07-envoy-gateway/envoy-deployment.yaml` - Manual Envoy deployment
- `kubernetes/07-envoy-gateway/envoy-service.yaml` - LoadBalancer service

### Phase 3 Files (New)
- `kubernetes/08-gateway-api/00-install-envoy-gateway.yaml` - Installation instructions
- `kubernetes/08-gateway-api/01-gatewayclass.yaml` - GatewayClass
- `kubernetes/08-gateway-api/02-gateway.yaml` - Gateway (replaces Deployment + Service)
- `kubernetes/08-gateway-api/03-httproute-customer.yaml` - Customer routes
- `kubernetes/08-gateway-api/04-httproute-product.yaml` - Product routes
- `kubernetes/08-gateway-api/05-httproute-auth-me.yaml` - User info route
- `kubernetes/08-gateway-api/06-httproute-keycloak.yaml` - Keycloak routes
- `kubernetes/08-gateway-api/07-securitypolicy-jwt.yaml` - JWT authentication
- `kubernetes/08-gateway-api/08-securitypolicy-extauth.yaml` - External authorization

## Next Steps After Phase 3

Once Phase 3 is working successfully:

1. **Remove Phase 2 Resources** (optional)
   - Keep files for reference
   - Or delete files if confident in Phase 3

2. **Enhance Security Policies**
   - Add rate limiting with RateLimitPolicy
   - Implement retry and timeout policies
   - Add circuit breaking

3. **Improve Observability**
   - Configure Prometheus metrics
   - Add distributed tracing
   - Set up logging aggregation

4. **Production Readiness**
   - Add resource requests/limits
   - Configure HorizontalPodAutoscaler
   - Implement health checks
   - Add NetworkPolicies

5. **Advanced Gateway API Features**
   - Request/response header manipulation
   - Traffic splitting (canary deployments)
   - Request mirroring
   - Cross-namespace routing with ReferenceGrant

## Resources

- **Kubernetes Gateway API**
  - [Official Documentation](https://gateway-api.sigs.k8s.io/)
  - [API Specification](https://gateway-api.sigs.k8s.io/reference/spec/)
  - [Guides and Tutorials](https://gateway-api.sigs.k8s.io/guides/)

- **Envoy Gateway**
  - [Official Documentation](https://gateway.envoyproxy.io/)
  - [Quickstart Guide](https://gateway.envoyproxy.io/latest/tasks/quickstart/)
  - [Security Tasks](https://gateway.envoyproxy.io/latest/tasks/security/)
  - [API Reference](https://gateway.envoyproxy.io/latest/api/extension_types/)

- **Project Resources**
  - [kubernetes/08-gateway-api/README.md](../kubernetes/08-gateway-api/README.md) - Detailed resource documentation
  - [docs/kubernetes-deployment.md](kubernetes-deployment.md) - General deployment guide

## Summary

Phase 3 successfully migrates from direct Envoy deployment to Kubernetes Gateway API, providing:
- ✅ Declarative, Kubernetes-native configuration
- ✅ Dynamic updates without pod restarts
- ✅ Standard, portable API
- ✅ Better separation of concerns
- ✅ Enhanced observability

The migration maintains all functionality from Phase 2 (JWT validation, external authz, routing) while providing a more maintainable and scalable architecture.

---

**Last Updated:** 2024
**Status:** Ready for deployment
**Phase:** 3 - Gateway API Migration
