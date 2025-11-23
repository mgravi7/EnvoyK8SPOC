# Script Permissions and Usage

This document explains how to make the Phase 3 scripts executable and use them.

## Make Scripts Executable (Linux/Mac/WSL)

Before using the Bash scripts, make them executable:

```bash
cd scripts/bash
chmod +x *.sh
```

Or individually:
```bash
chmod +x build-images.sh
chmod +x deploy-k8s-phase2.sh
chmod +x deploy-k8s-phase3.sh
chmod +x cleanup-k8s.sh
chmod +x verify-deployment.sh
chmod +x test-endpoints.sh
```

## Script Usage

### Phase 3 Deployment

**Prerequisites:**
1. Install Envoy Gateway (one-time per cluster):
   ```bash
   kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml
   kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
   ```

2. Verify Envoy Gateway is running:
   ```bash
   kubectl get pods -n envoy-gateway-system
   ```

**Deployment:**

```bash
# Linux/Mac/WSL
cd scripts/bash
./deploy-k8s-phase3.sh

# Windows PowerShell
cd scripts\powershell
.\deploy-k8s-phase3.ps1
```

**What the script does:**
1. ✅ Checks if Envoy Gateway is installed
2. ✅ Detects Phase 2 Envoy conflicts (prompts to delete if found)
3. ✅ Deploys namespace, configs, secrets
4. ✅ Deploys Redis, Keycloak, authz-service
5. ✅ Deploys backend services (customer, product)
6. ✅ Creates GatewayClass and Gateway
7. ✅ Creates HTTPRoutes for all services
8. ✅ Applies SecurityPolicies (JWT + ext_authz)
9. ✅ Waits for Gateway to be ready
10. ✅ Displays status and next steps

### Verification

```bash
# Linux/Mac/WSL
./verify-deployment.sh

# Windows PowerShell
.\verify-deployment.ps1
```

**What the script checks:**
- ✅ Detects Phase 2 or Phase 3 deployment
- ✅ Pod status (all Running?)
- ✅ Services and endpoints
- ✅ ConfigMaps and Secrets
- ✅ Gateway status (Phase 3)
- ✅ HTTPRoutes (Phase 3)
- ✅ SecurityPolicies (Phase 3)
- ✅ Recent logs from all services

### Testing

```bash
# Linux/Mac/WSL
./test-endpoints.sh

# Windows PowerShell
.\test-endpoints.ps1
```

### Cleanup

```bash
# Linux/Mac/WSL
./cleanup-k8s.sh

# Windows PowerShell
.\cleanup-k8s.ps1
```

**What the script removes:**
- ✅ Phase 3 Gateway API resources (if present)
- ✅ Phase 2 Envoy resources (if present)
- ✅ Entire api-gateway-poc namespace
- ✅ All backend services, configs, secrets

**Note:** Envoy Gateway operator (envoy-gateway-system) is NOT deleted and can be reused.

## Common Workflows

### First Time Setup

```bash
# 1. Install Envoy Gateway
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# 2. Build images
cd scripts/bash
./build-images.sh

# 3. Deploy Phase 3
./deploy-k8s-phase3.sh

# 4. Verify
./verify-deployment.sh

# 5. Test
./test-endpoints.sh
```

### Switching from Phase 2 to Phase 3

```bash
# Option 1: Let deploy script handle it (recommended)
cd scripts/bash
./deploy-k8s-phase3.sh
# Script will detect Phase 2 and prompt to delete

# Option 2: Manual cleanup
./cleanup-k8s.sh
./deploy-k8s-phase3.sh
```

### Switching from Phase 3 to Phase 2

```bash
cd scripts/bash
./cleanup-k8s.sh
./deploy-k8s-phase2.sh
```

### Redeploying Phase 3

```bash
cd scripts/bash
./cleanup-k8s.sh
./deploy-k8s-phase3.sh
```

### Updating Gateway API Resources

Phase 3 supports dynamic updates without pod restarts:

```bash
# Edit a resource
vi kubernetes/08-gateway-api/03-httproute-customer.yaml

# Apply the change
kubectl apply -f kubernetes/08-gateway-api/03-httproute-customer.yaml

# Verify the change
kubectl describe httproute customer-route -n api-gateway-poc
```

No need to restart pods or redeploy!

## Troubleshooting Scripts

### Script says Envoy Gateway not installed

```bash
# Install Envoy Gateway
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml

# Wait for it to be ready
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify
kubectl get pods -n envoy-gateway-system
```

### Script detects Phase 2 conflict

The script will prompt:
```
WARNING: Phase 2 Envoy deployment is still running!
Do you want to delete Phase 2 Envoy resources? (y/N)
```

Choose `y` to automatically delete Phase 2 resources, or manually clean up:
```bash
kubectl delete -f kubernetes/07-envoy-gateway/
```

### Permission denied (Linux/Mac)

```bash
cd scripts/bash
chmod +x *.sh
```

### Script not found (Windows)

Make sure you're in the correct directory:
```powershell
cd scripts\powershell
Get-ChildItem *.ps1  # List scripts
.\deploy-k8s-phase3.ps1  # Run with .\
```

### PowerShell execution policy error

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Then run script
.\deploy-k8s-phase3.ps1
```

## Script Output

### Successful Deployment

```
========================================
Step 8: Deploying Gateway API Resources
========================================
Creating GatewayClass...
gatewayclass.gateway.networking.k8s.io/envoy-gateway created

Creating Gateway...
gateway.gateway.networking.k8s.io/api-gateway created
Gateway api-gateway is ready!

Creating HTTPRoutes...
httproute.gateway.networking.k8s.io/customer-route created
httproute.gateway.networking.k8s.io/product-route created
httproute.gateway.networking.k8s.io/auth-me-route created
httproute.gateway.networking.k8s.io/keycloak-route created

Applying Security Policies...
securitypolicy.gateway.envoyproxy.io/jwt-authentication created
securitypolicy.gateway.envoyproxy.io/external-authorization created

================================
Deployment Complete!
================================
```

### Verification Output

```
Detected: Phase 3 (Gateway API)

Gateway:
NAME          CLASS           ADDRESS      PROGRAMMED   AGE
api-gateway   envoy-gateway   localhost    True         2m

HTTPRoutes:
NAME             HOSTNAMES   AGE
customer-route   ["*"]       2m
product-route    ["*"]       2m
auth-me-route    ["*"]       2m
keycloak-route   ["*"]       2m

Status: ✓ All pods are running!
```

## Help and Support

- **Deployment Guide:** `docs/kubernetes-deployment.md`
- **Migration Guide:** `docs/gateway-api-migration.md`
- **Gateway API Reference:** `kubernetes/08-gateway-api/README.md`
- **Project Plan:** `project-plan.md`

For issues, check the troubleshooting sections in the documentation.
