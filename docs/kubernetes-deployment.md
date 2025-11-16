# Kubernetes Deployment Guide - Phase 2

This guide covers deploying EnvoyK8SPOC to Kubernetes using Docker Desktop with direct Envoy deployment.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Deployment Steps](#detailed-deployment-steps)
- [Verification](#verification)
- [Testing](#testing)
- [Accessing Services](#accessing-services)
- [Common Issues](#common-issues)

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

## Quick Start

### 1. Build Images

**Linux/Mac/WSL:**
```bash
cd scripts/bash
chmod +x *.sh
./build-images.sh
```

**Windows PowerShell:**
```powershell
cd scripts\powershell
.\build-images.ps1
```

### 2. Deploy to Kubernetes

**Linux/Mac/WSL:**
```bash
./deploy-k8s-phase2.sh
```

**Windows PowerShell:**
```powershell
.\deploy-k8s-phase2.ps1
```

### 3. Verify Deployment

**Linux/Mac/WSL:**
```bash
./verify-deployment.sh
```

**Windows PowerShell:**
```powershell
.\verify-deployment.ps1
```

### 4. Test Endpoints

**Linux/Mac/WSL:**
```bash
./test-endpoints.sh
```

**Windows PowerShell:**
```powershell
.\test-endpoints.ps1
```

## Detailed Deployment Steps

### Step 1: Build Docker Images

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

### Step 2: Deploy Kubernetes Resources

Resources are deployed in this order:

1. **Namespace** (api-gateway-poc)
   ```bash
   kubectl apply -f kubernetes/00-namespace/
   ```

2. **ConfigMaps and Secrets**
   ```bash
   kubectl apply -f kubernetes/01-config/
   ```

3. **Storage** (Redis PVC)
   ```bash
   kubectl apply -f kubernetes/02-storage/
   ```

4. **Redis**
   ```bash
   kubectl apply -f kubernetes/03-data/
   kubectl wait --for=condition=available deployment/redis -n api-gateway-poc --timeout=120s
   ```

5. **Keycloak**
   ```bash
   kubectl apply -f kubernetes/04-iam/
   kubectl wait --for=condition=available deployment/keycloak -n api-gateway-poc --timeout=180s
   ```

6. **Authorization Service**
   ```bash
   kubectl apply -f kubernetes/05-authz/
   kubectl wait --for=condition=available deployment/authz-service -n api-gateway-poc --timeout=120s
   ```

7. **Backend Services**
   ```bash
   kubectl apply -f kubernetes/06-services/
   kubectl wait --for=condition=available deployment/customer-service -n api-gateway-poc --timeout=120s
   kubectl wait --for=condition=available deployment/product-service -n api-gateway-poc --timeout=120s
   ```

8. **Envoy Gateway**
   ```bash
   kubectl apply -f kubernetes/07-envoy-gateway/
   kubectl wait --for=condition=available deployment/envoy -n api-gateway-poc --timeout=120s
   ```

Or use the automated script:
```bash
./scripts/bash/deploy-k8s-phase2.sh
```

### Step 3: Verify All Pods Are Running

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

### Step 4: Check Services

```bash
kubectl get svc -n api-gateway-poc
```

Expected output:
```
NAME               TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
authz-service      ClusterIP      10.x.x.x        <none>        9000/TCP
customer-service   ClusterIP      10.x.x.x        <none>        8000/TCP
envoy              LoadBalancer   10.x.x.x        localhost     8080:xxx/TCP,9901:xxx/TCP
keycloak           LoadBalancer   10.x.x.x        localhost     8180:xxx/TCP
product-service    ClusterIP      10.x.x.x        <none>        8000/TCP
redis              ClusterIP      10.x.x.x        <none>        6379/TCP
```

## Verification

### Check Pod Logs

```bash
# Redis
kubectl logs -f deployment/redis -n api-gateway-poc

# Keycloak
kubectl logs -f deployment/keycloak -n api-gateway-poc

# AuthZ Service
kubectl logs -f deployment/authz-service -n api-gateway-poc

# Customer Service
kubectl logs -f deployment/customer-service -n api-gateway-poc

# Product Service
kubectl logs -f deployment/product-service -n api-gateway-poc

# Envoy
kubectl logs -f deployment/envoy -n api-gateway-poc
```

### Check Health Endpoints

```bash
# Envoy admin ready check
curl http://localhost:9901/ready

# Keycloak health
curl http://localhost:8180/health/ready
```

### Check Service Endpoints (via Envoy)

```bash
# Products (no auth required)
curl http://localhost:8080/products

# Customers (requires auth - should return 401)
curl http://localhost:8080/customers
```

## Testing

### Get JWT Token from Keycloak

```bash
TOKEN=$(curl -s -X POST "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" \
  | jq -r '.access_token')

echo $TOKEN
```

### Test Authenticated Request

```bash
# Customer service (requires JWT)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/customers

# Specific customer
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/customers/1
```

### Run Integration Tests

1. Update test configuration in `tests/integration/conftest.py`:
   ```python
   GATEWAY_BASE_URL = "http://localhost:8080"
   ```

2. Run tests:
   ```bash
   cd tests/integration
   pytest -v
   ```

Expected: All 90 tests should pass.

## Accessing Services

### Keycloak Admin Console
- URL: http://localhost:8180
- Username: `admin`
- Password: `admin`

**WARNING: Development credentials only - DO NOT use in production**

### Envoy Gateway
- API Gateway: http://localhost:8080
- Admin Interface: http://localhost:9901

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
- Admin Console: http://localhost:8180
- Token endpoint: http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token
- JWKS: http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/certs

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
# 2. Insufficient resources - increase Docker Desktop memory
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
# Or use port-forward instead:
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080
kubectl port-forward -n api-gateway-poc svc/keycloak 8180:8180
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

### Cannot Access Services

**Symptom:** curl to localhost:8080 fails

**Solutions:**
```bash
# 1. Verify pods are running
kubectl get pods -n api-gateway-poc

# 2. Check service endpoints
kubectl get endpoints -n api-gateway-poc

# 3. Verify LoadBalancer IP
kubectl get svc envoy -n api-gateway-poc

# 4. Try port-forward
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080

# 5. Check Envoy logs
kubectl logs -f deployment/envoy -n api-gateway-poc
```

### Tests Failing

**Symptom:** Integration tests fail after deployment

**Solutions:**
```bash
# 1. Verify GATEWAY_BASE_URL is correct
# Edit tests/integration/conftest.py
GATEWAY_BASE_URL = "http://localhost:8080"

# 2. Wait for all pods to be ready
kubectl get pods -n api-gateway-poc

# 3. Test manually first
curl http://localhost:8080/products

# 4. Get fresh token
TOKEN=$(curl -s -X POST "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" ...)

# 5. Run specific test
pytest tests/integration/test_customer_service.py::TestCustomerService::test_customers_list_access -v
```

## Clean Up

To remove all deployed resources:

**Linux/Mac/WSL:**
```bash
./scripts/bash/cleanup-k8s.sh
```

**Windows PowerShell:**
```powershell
.\scripts\powershell\cleanup-k8s.ps1
```

This deletes the entire `api-gateway-poc` namespace and all resources within it.

## Next Steps

Once Phase 2 is working successfully:

1. Review what you've learned about Kubernetes deployments
2. Understand how services communicate via DNS
3. Explore kubectl commands for debugging
4. Prepare for Phase 3: Migration to Gateway API

See `docs/gateway-api-migration.md` for Phase 3 planning.

## Reference

- Kubernetes manifests: `kubernetes/`
- Deployment scripts: `scripts/`
- Troubleshooting: `docs/troubleshooting.md`
- Project plan: `project-plan.md`
