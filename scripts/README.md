# EnvoyK8SPOC Deployment Scripts

This directory contains deployment automation scripts for EnvoyK8SPOC (Gateway API / Phase 3).

## Directory Structure

```
scripts/
+-- bash/                   # Linux/Mac/WSL scripts
|   +-- build-images.sh
|   +-- deploy-k8s.sh       # Deploys Phase 3 (Gateway API)
|   +-- verify-deployment.sh
|   +-- test-endpoints.sh
|   +-- cleanup-k8s.sh
|
+-- powershell/             # Windows PowerShell scripts
    +-- build-images.ps1
    +-- deploy-k8s.ps1      # Deploys Phase 3 (Gateway API)
    +-- verify-deployment.ps1
    +-- test-endpoints.ps1
    +-- cleanup-k8s.ps1
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

### Step 2: Install Envoy Gateway (Helm recommended)

```bash
# Install Envoy Gateway via Helm (v1.6.0)
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 --create-namespace --namespace envoy-gateway-system
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

### Step 3: Deploy to Kubernetes (Phase 3)

**Bash:**
```bash
./deploy-k8s.sh
```

**PowerShell:**
```powershell
.\deploy-k8s.ps1
```

This deploys all resources in the correct order and waits for readiness.

### Step 4: Verify Deployment

**Bash:**
```bash
./verify-deployment.sh
```

**PowerShell:**
```powershell
.\verify-deployment.ps1
```

### Step 5: Test Endpoints

**Bash:**
```bash
./test-endpoints.sh
```

**PowerShell:**
```powershell
.\test-endpoints.ps1
```

### Step 6: Cleanup

**Bash:**
```bash
./cleanup-k8s.sh
```

**PowerShell:**
```powershell
.\cleanup-k8s.ps1
```

This removes Phase 3 resources (namespace, Gateway, HTTPRoutes, SecurityPolicies) but keeps the Envoy Gateway operator for reuse.

## Notes
- This repository standardizes on the Kubernetes Gateway API (Phase 3). The legacy Phase 2 direct Envoy deployment manifests have been removed to reduce clutter. Keep `docker-compose.yml` for native Docker runs.
- Scripts assume Envoy Gateway operator v1.6.0+ is installed via Helm.
- Run `pytest -q` in `tests/` to execute the full test suite.
