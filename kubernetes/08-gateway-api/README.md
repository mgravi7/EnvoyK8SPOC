# Phase 3: Kubernetes Gateway API Resources

This directory contains Kubernetes Gateway API resources for Phase 3 deployment using Envoy Gateway.

## Overview

Phase 3 replaces the direct Envoy Proxy deployment (Phase 2) with Kubernetes Gateway API resources. This provides:
- **Declarative Configuration**: All routing and security via Kubernetes CRDs
- **Dynamic Updates**: Change routes without pod restarts
- **Standard API**: Portable across gateway implementations
- **Better Integration**: Native Kubernetes resource management

## Architecture

```
Gateway API (Phase 3)
|
+-- GatewayClass (envoy-gateway)
|   +-- References Envoy Gateway controller
|
+-- Gateway (api-gateway)
|   +-- HTTP Listener on port 8080
|   +-- Automatically creates Envoy Deployment + Service
|
+-- SecurityPolicy (Gateway-level)
|   +-- JWT Authentication (Keycloak JWKS)
|   +-- External Authorization (authz-service)
|
+-- HTTPRoutes
    +-- customer-route (/customers/* → customer-service:8000)
    +-- product-route (/products/* → product-service:8000)
    +-- auth-me-route (/auth/me → authz-service:9000/authz/me)
    +-- keycloak-route (/auth/* → keycloak:8180/)
```

## Files

### Installation & Core Resources
- **00-install-envoy-gateway.yaml** - Installation instructions and commands
- **01-gatewayclass.yaml** - GatewayClass referencing Envoy Gateway controller
- **02-gateway.yaml** - Gateway resource with HTTP listener (replaces Phase 2 Envoy Deployment)

### Routing Resources (HTTPRoutes)
- **03-httproute-customer.yaml** - Customer service routes
- **04-httproute-product.yaml** - Product service routes
- **05-httproute-auth-me.yaml** - User info endpoint route
- **06-httproute-keycloak.yaml** - Keycloak authentication routes (no auth required)

### Security Resources
- **07-securitypolicy-jwt.yaml** - JWT authentication (Keycloak JWKS)
- **08-securitypolicy-extauth.yaml** - External authorization (RBAC via authz-service)

## Deployment Order

1. **Install Envoy Gateway** (one-time per cluster):
   ```bash
   kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml
   kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
   ```

2. **Deploy Gateway API Resources**:
   ```bash
   # Create GatewayClass
   kubectl apply -f 01-gatewayclass.yaml
   
   # Create Gateway (this creates the Envoy proxy automatically)
   kubectl apply -f 02-gateway.yaml
   
   # Create HTTPRoutes
   kubectl apply -f 03-httproute-customer.yaml
   kubectl apply -f 04-httproute-product.yaml
   kubectl apply -f 05-httproute-auth-me.yaml
   kubectl apply -f 06-httproute-keycloak.yaml
   
   # Apply Security Policies
   kubectl apply -f 07-securitypolicy-jwt.yaml
   kubectl apply -f 08-securitypolicy-extauth.yaml
   ```

3. **Verify Deployment**:
   ```bash
   # Check Gateway status
   kubectl get gateway -n api-gateway-poc
   kubectl describe gateway api-gateway -n api-gateway-poc
   
   # Check HTTPRoutes
   kubectl get httproute -n api-gateway-poc
   
   # Check SecurityPolicies
   kubectl get securitypolicy -n api-gateway-poc
   
   # Check generated Envoy resources
   kubectl get pods -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
   kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
   ```

## Key Differences from Phase 2

| Aspect | Phase 2 | Phase 3 |
|--------|---------|---------|
| **Configuration** | Static envoy.yaml in ConfigMap | Dynamic Gateway API CRDs |
| **Deployment** | Manual Envoy Deployment | Auto-created by Gateway |
| **Routing** | Envoy route_config | HTTPRoute CRDs |
| **Security** | Envoy http_filters | SecurityPolicy CRDs |
| **Updates** | Requires pod restart | Dynamic, no restart |
| **Management** | kubectl + envoy.yaml editing | kubectl only |

## Security Policies

### JWT Authentication Policy
- **Applied to**: Gateway level (affects all routes)
- **Provider**: Keycloak (JWKS endpoint)
- **Claims forwarded**: email, preferred_username, roles
- **Issuer**: `http://localhost:8180/realms/api-gateway-poc`

### External Authorization Policy
- **Applied to**: Gateway level (affects all routes)
- **Service**: authz-service:9000/authz/roles
- **Headers sent**: authorization, x-request-id, x-user-email
- **Headers received**: x-user-email, x-user-roles
- **Fail mode**: Closed (deny on authz service failure)

### Exception Handling
The Keycloak route (`/auth/*`) should not require JWT validation since it provides the authentication endpoint itself. This is handled by:
- Route priority/ordering
- Or by applying SecurityPolicy at HTTPRoute level instead of Gateway level (future enhancement)

## Testing

After deployment, test the gateway:

```bash
# Get LoadBalancer IP (Docker Desktop uses localhost)
kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

# Test Keycloak (no auth required)
curl http://localhost:8080/auth/realms/api-gateway-poc

# Get JWT token
TOKEN=$(curl -X POST http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token \
  -d "client_id=customer-client" \
  -d "client_secret=customer-secret-key" \
  -d "username=alice@example.com" \
  -d "password=alice123" \
  -d "grant_type=password" | jq -r '.access_token')

# Test customer service (requires JWT + RBAC)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/customers

# Test product service (requires JWT + RBAC)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/products
```

## Troubleshooting

### Gateway not ready
```bash
# Check Gateway status
kubectl describe gateway api-gateway -n api-gateway-poc

# Check Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway

# Check generated Envoy proxy logs
kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway
```

### HTTPRoute not working
```bash
# Check HTTPRoute status
kubectl describe httproute customer-route -n api-gateway-poc

# Verify backend service exists
kubectl get svc customer-service -n api-gateway-poc

# Check Envoy configuration
kubectl port-forward -n api-gateway-poc svc/envoy-api-gateway-xxxxx 19000:19000
# Then access: http://localhost:19000/config_dump
```

### SecurityPolicy not applied
```bash
# Check SecurityPolicy status
kubectl describe securitypolicy jwt-authentication -n api-gateway-poc
kubectl describe securitypolicy external-authorization -n api-gateway-poc

# Verify authz-service is accessible
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc \
  -- curl http://authz-service:9000/authz/health
```

### JWT validation failing
```bash
# Check Keycloak JWKS endpoint is accessible from Envoy
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc \
  -- curl http://keycloak.api-gateway-poc.svc.cluster.local:8180/realms/api-gateway-poc/protocol/openid-connect/certs

# Check Envoy logs for JWT errors
kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway | grep -i jwt
```

## Resources

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Envoy Gateway Security Tasks](https://gateway.envoyproxy.io/latest/tasks/security/)
- [Gateway API Security Model](https://gateway-api.sigs.k8s.io/guides/security-model/)

## Next Steps

After successful Phase 3 deployment:
1. Remove Phase 2 Envoy resources (Deployment, ConfigMap, Service)
2. Update documentation with lessons learned
3. Consider Phase 4 enhancements (rate limiting, observability, etc.)
