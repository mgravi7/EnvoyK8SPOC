# Script Permissions and Usage

This document explains how to make the Gateway API scripts executable and use them.

## Make Scripts Executable (Linux/Mac/WSL)

Before using the Bash scripts, make them executable:

```bash
cd scripts/bash
chmod +x *.sh
```

Or individually:
```bash
chmod +x build-images.sh
chmod +x deploy-k8s.sh
chmod +x cleanup-k8s.sh
chmod +x verify-deployment.sh
chmod +x test-endpoints.sh
```

## Script Usage

### Gateway API Deployment (Phase 3)

**Prerequisites:**
1. Install Envoy Gateway (one-time per cluster):
   ```bash
   # Helm (recommended)
   helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 --create-namespace --namespace envoy-gateway-system
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
./deploy-k8s.sh

# Windows PowerShell
cd scripts\powershell
.\deploy-k8s.ps1
```

**What the script does:**
1. ✅ Checks if Envoy Gateway is installed
2. ✅ Deploys namespace, configs, secrets
3. ✅ Deploys Redis, Keycloak, authz-service
4. ✅ Deploys backend services (customer, product)
5. ✅ Creates GatewayClass and Gateway
6. ✅ Creates HTTPRoutes for all services
7. ✅ Applies SecurityPolicies (JWT + ext_authz)
8. ✅ Waits for Gateway to be ready
9. ✅ Displays status and next steps

### Verification

```bash
# Linux/Mac/WSL
./verify-deployment.sh

# Windows PowerShell
.\verify-deployment.ps1
```

**What the script checks:**
- ✓ Pod status (all Running?)
- ✓ Services and endpoints
- ✓ ConfigMaps and Secrets
- ✓ Gateway status
- ✓ HTTPRoutes
- ✓ SecurityPolicies
- ✓ Recent logs from each service

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
- ✅ Gateway API resources (Gateway, HTTPRoutes, SecurityPolicies) in `api-gateway-poc`
- ✅ The `api-gateway-poc` namespace and its resources

**Note:** Envoy Gateway operator (envoy-gateway-system) is NOT deleted and can be reused.

## Common Workflows

### First Time Setup

```bash
# 1. Install Envoy Gateway (Helm)
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 --create-namespace --namespace envoy-gateway-system
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# 2. Build images
cd scripts/bash
./build-images.sh

# 3. Deploy Gateway API resources
./deploy-k8s.sh

# 4. Verify
./verify-deployment.sh

# 5. Test
./test-endpoints.sh
```

### Redeploying

```bash
cd scripts/bash
./cleanup-k8s.sh
./deploy-k8s.sh
```

### Updating Gateway API Resources

Gateway API supports dynamic updates without pod restarts:

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
# Install Envoy Gateway (Helm)
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 --create-namespace --namespace envoy-gateway-system
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify
kubectl get pods -n envoy-gateway-system
```

### Legacy direct-Envoy resources detected

If legacy direct-Envoy resources remain from an earlier workflow the deploy/cleanup scripts will handle removal, or you can remove them manually. Legacy artifacts have been archived in `docs/archive/`.

```bash
# Manual cleanup of legacy direct-Envoy manifests (only if present)
kubectl delete -f kubernetes/07-envoy-gateway/ || true
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
.\deploy-k8s.ps1  # Run with .\
```

### PowerShell execution policy error

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Then run script
.\deploy-k8s.ps1
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

## Help and Support

- **Deployment Guide:** `docs/kubernetes-deployment.md`
- **Gateway API resources:** `kubernetes/08-gateway-api/` (see files in that directory)
- **Troubleshooting:** `docs/troubleshooting.md`

For issues, check the troubleshooting sections in the documentation.
