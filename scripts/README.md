# EnvoyK8SPOC Deployment Scripts

This directory contains deployment automation scripts for EnvoyK8SPOC Phase 2 (Kubernetes migration).

## Directory Structure

```
scripts/
+-- bash/                   # Linux/Mac/WSL scripts
|   +-- build-images.sh
|   +-- deploy-k8s-phase2.sh
|   +-- verify-deployment.sh
|   +-- test-endpoints.sh
|   +-- cleanup-k8s.sh
|
+-- powershell/             # Windows PowerShell scripts
    +-- build-images.ps1
    +-- deploy-k8s-phase2.ps1
    +-- verify-deployment.ps1
    +-- test-endpoints.ps1
    +-- cleanup-k8s.ps1
    +-- open-devshell-solution.ps1
```

## Prerequisites

### All Platforms
- Docker Desktop with Kubernetes enabled
- kubectl installed and configured
- Git

### Linux/Mac/WSL (Bash Scripts)
- Bash shell
- curl (for endpoint testing)

### Windows (PowerShell Scripts)
- PowerShell 5.1+ or PowerShell Core 7+
- Scripts work in both Windows PowerShell and PowerShell Core

## Quick Start

### Step 1: Build Docker Images

**Bash:**
```bash
cd scripts/bash
chmod +x *.sh
./build-images.sh
```

**PowerShell:**
```powershell
cd scripts\powershell
.\build-images.ps1
```

This builds all Docker images locally:
- customer-service:latest
- product-service:latest
- authz-service:latest
- keycloak:latest
- envoy:latest

### Step 2: Deploy to Kubernetes

**Bash:**
```bash
./deploy-k8s-phase2.sh
```

**PowerShell:**
```powershell
.\deploy-k8s-phase2.ps1
```

This deploys all resources in the correct order:
1. Namespace (api-gateway-poc)
2. ConfigMaps and Secrets
3. Redis with PVC
4. Keycloak
5. Authorization Service
6. Customer and Product Services
7. Envoy Gateway

The script waits for each component to be ready before proceeding.

### Step 3: Verify Deployment

**Bash:**
```bash
./verify-deployment.sh
```

**PowerShell:**
```powershell
.\verify-deployment.ps1
```

This checks:
- Pod status (all should be Running)
- Service endpoints
- ConfigMaps and Secrets
- Recent logs from each service

### Step 4: Test Endpoints

**Bash:**
```bash
./test-endpoints.sh
```

**PowerShell:**
```powershell
.\test-endpoints.ps1
```

This tests:
- Envoy admin endpoint
- Keycloak health endpoint
- Service routing through Envoy
- JWT token retrieval
- Authenticated API calls

## Script Descriptions

### build-images.sh / build-images.ps1
Builds all Docker images from source code. Images are automatically available to Docker Desktop Kubernetes.

**Usage:**
```bash
./build-images.sh        # Bash
.\build-images.ps1       # PowerShell
```

### deploy-k8s-phase2.sh / deploy-k8s-phase2.ps1
Deploys all Kubernetes manifests in the correct order with wait logic.

**Usage:**
```bash
./deploy-k8s-phase2.sh   # Bash
.\deploy-k8s-phase2.ps1  # PowerShell
```

**What it does:**
- Creates namespace
- Applies ConfigMaps and Secrets
- Creates PVC for Redis
- Deploys services in dependency order
- Waits for each deployment to be ready
- Shows final status

### verify-deployment.sh / verify-deployment.ps1
Comprehensive deployment health check.

**Usage:**
```bash
./verify-deployment.sh   # Bash
.\verify-deployment.ps1  # PowerShell
```

**What it checks:**
- Namespace exists
- All pods are running
- Services have endpoints
- ConfigMaps and Secrets are present
- PVC is bound
- Recent logs from all services

### test-endpoints.sh / test-endpoints.ps1
Tests service endpoints and authentication flow.

**Usage:**
```bash
./test-endpoints.sh      # Bash
.\test-endpoints.ps1     # PowerShell
```

**What it tests:**
- Envoy admin endpoint (/ready)
- Keycloak health endpoint
- Service routing (with and without auth)
- JWT token retrieval from Keycloak
- Authenticated API call to customer service

### cleanup-k8s.sh / cleanup-k8s.ps1
Removes all Phase 2 resources from Kubernetes.

**Usage:**
```bash
./cleanup-k8s.sh         # Bash
.\cleanup-k8s.ps1        # PowerShell
```

**Warning:** This deletes the entire `api-gateway-poc` namespace and all resources within it.

## Accessing Services

After deployment, services are available at:

- **Keycloak Admin Console:** http://localhost:8180
  - Username: admin
  - Password: admin

- **Envoy Gateway:** http://localhost:8080
  - Customer API: http://localhost:8080/customers (requires auth)
  - Product API: http://localhost:8080/products
  - Auth endpoints: http://localhost:8080/auth/*

- **Envoy Admin:** http://localhost:9901
  - Ready check: http://localhost:9901/ready
  - Stats: http://localhost:9901/stats

## Manual kubectl Commands

### Check pod status
```bash
kubectl get pods -n api-gateway-poc
```

### View logs
```bash
kubectl logs -f deployment/envoy -n api-gateway-poc
kubectl logs -f deployment/keycloak -n api-gateway-poc
kubectl logs -f deployment/authz-service -n api-gateway-poc
```

### Describe resources
```bash
kubectl describe pod <pod-name> -n api-gateway-poc
kubectl describe deployment <deployment-name> -n api-gateway-poc
```

### Port forwarding (alternative to LoadBalancer)
```bash
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080
kubectl port-forward -n api-gateway-poc svc/keycloak 8180:8180
```

### Delete specific resources
```bash
kubectl delete deployment <name> -n api-gateway-poc
kubectl delete service <name> -n api-gateway-poc
```

## Running Integration Tests

After deployment, update test configuration and run integration tests:

1. Update `tests/integration/conftest.py`:
   ```python
   GATEWAY_BASE_URL = "http://localhost:8080"
   ```

2. Run tests:
   ```bash
   pytest tests/integration/
   ```

## Troubleshooting

### Pods not starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n api-gateway-poc

# Check logs
kubectl logs <pod-name> -n api-gateway-poc

# Check if image exists
docker images | grep <service-name>
```

### LoadBalancer pending
Docker Desktop should automatically assign localhost IPs to LoadBalancer services. If stuck in "Pending":
```bash
# Check service status
kubectl get svc -n api-gateway-poc

# Restart Docker Desktop
```

### Cannot connect to services
```bash
# Verify services have endpoints
kubectl get endpoints -n api-gateway-poc

# Check if pods are ready
kubectl get pods -n api-gateway-poc

# Try port-forward instead of LoadBalancer
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080
```

### Keycloak taking too long to start
Keycloak can take 90-120 seconds to start on first run. Check logs:
```bash
kubectl logs -f deployment/keycloak -n api-gateway-poc
```

Wait for: "Keycloak ... started"

### Redis connection errors
```bash
# Check Redis is running
kubectl get pods -n api-gateway-poc | grep redis

# Check authz-service logs
kubectl logs -f deployment/authz-service -n api-gateway-poc

# Verify Redis service
kubectl get svc redis -n api-gateway-poc
```

## Development Workflow

### Typical workflow:
1. Make code changes to services
2. Test locally with Docker Compose (optional)
3. Rebuild images: `./build-images.sh`
4. Redeploy to Kubernetes: `./deploy-k8s-phase2.sh`
5. Verify: `./verify-deployment.sh`
6. Test: `./test-endpoints.sh`
7. Run integration tests: `pytest tests/integration/`

### Quick redeploy (without cleanup):
```bash
# Rebuild single service
docker build -t customer-service:latest -f services/customer-service/Dockerfile services

# Force pod restart
kubectl rollout restart deployment/customer-service -n api-gateway-poc

# Watch rollout status
kubectl rollout status deployment/customer-service -n api-gateway-poc
```

## Security Notes

**WARNING: Development Environment Only**

- Secrets are base64-encoded in manifests (NOT encrypted)
- Default credentials (admin/admin) are used
- DO NOT use these configurations in production

**Production requirements:**
- Use Kubernetes Secrets encryption at rest
- Integrate with external secret stores (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault)
- Change all default credentials
- Enable SSL/TLS
- Use proper authentication/authorization for Kubernetes API

## Next Steps

After successful Phase 2 deployment:
1. Review Phase 2 learnings
2. Plan Phase 3 migration to Gateway API
3. Install Envoy Gateway operator
4. Migrate from direct Envoy deployment to Gateway API CRDs
