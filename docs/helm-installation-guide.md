# Envoy Gateway Helm Installation Guide

This guide covers installing Envoy Gateway using Helm for the EnvoyK8SPOC project. Helm is the recommended installation method for Envoy Gateway v1.6.0+ as it handles large CRDs better than kubectl apply.

## Table of Contents
- [Why Helm?](#why-helm)
- [Prerequisites](#prerequisites)
- [Installation Steps](#installation-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)
- [Upgrading](#upgrading)
- [Reference](#reference)

---

## Why Helm?

### Benefits of Helm Installation

1. **Handles Large CRDs:** Envoy Gateway v1.6.0+ includes CRDs with large OpenAPI schemas (~1.2 MB) that exceed Kubernetes API server limits when using `kubectl apply`. Helm handles these gracefully.

2. **Version Management:** Helm tracks releases and makes upgrades/rollbacks easier.

3. **Declarative Configuration:** Helm values allow easy customization without editing manifests.

4. **Official Support:** Envoy Gateway team publishes official Helm charts via OCI registry.

### Issues with kubectl apply

The `kubectl apply` method fails for Envoy Gateway v1.6.0+ with this error:

```
The CustomResourceDefinition "envoyproxies.gateway.envoyproxy.io" is invalid: 
metadata.annotations: Too long: may not be more than 262144 bytes
```

This is due to the CRD's OpenAPI schema size, not actual metadata annotations. Helm bypasses this limitation.

---

## Prerequisites

### Required Software

- **Windows 11** or macOS or Linux
- **Docker Desktop** with Kubernetes enabled
- **kubectl** (installed with Docker Desktop)
- **Helm 3.x** (installation covered below)

### Install Helm

**Windows 11 (recommended):**

```powershell
# Install via Windows Package Manager (winget)
winget install Helm.Helm

# Verify installation
helm version
```

**Windows (alternative via Chocolatey):**

```powershell
choco install kubernetes-helm
helm version
```

**macOS:**

```bash
# Install via Homebrew
brew install helm

# Verify installation
helm version
```

**Linux:**

```bash
# Download and install
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

Expected output:
```
version.BuildInfo{Version:"v3.16.x", ...}
```

---

## Installation Steps

### Step 1: Clean Up Existing Gateway API CRDs (If Applicable)

If you previously attempted to install Envoy Gateway via kubectl or have conflicting CRDs, clean them up:

```powershell
# Check for existing Gateway API CRDs
kubectl get crd | Select-String "gateway"

# Delete all Gateway-related CRDs
kubectl delete crd $(kubectl get crd -o name | Select-String "gateway") --ignore-not-found=true

# Verify cleanup
kubectl get crd | Select-String "gateway"
```

Expected: No output (all Gateway CRDs removed)

### Step 2: Install Envoy Gateway via Helm

**Install from OCI registry (recommended):**

```powershell
# Install Envoy Gateway v1.6.0
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.6.0 `
  --create-namespace `
  --namespace envoy-gateway-system
```

**Expected output:**

```
Pulled: docker.io/envoyproxy/gateway-helm:v1.6.0
Digest: sha256:905eced000d4b2acb78f802f5d03af32a08d30478808c20d522ffa735476bc5d
NAME: envoy-gateway
LAST DEPLOYED: Sun Nov 23 20:20:15 2025
NAMESPACE: envoy-gateway-system
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
**************************************************************************
*** PLEASE BE PATIENT: Envoy Gateway may take a few minutes to install ***
**************************************************************************

Envoy Gateway is an open source project for managing Envoy Proxy as a standalone or Kubernetes-based application gateway.

Thank you for installing Envoy Gateway! 🎉
...
```

### Step 3: Wait for Envoy Gateway to be Ready

```powershell
# Wait for deployment to be available (timeout: 5 minutes)
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Check pod status
kubectl get pods -n envoy-gateway-system
```

**Expected output:**

```
NAME                             READY   STATUS    RESTARTS   AGE
envoy-gateway-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 4: Verify Helm Release

```powershell
# List Helm releases in the namespace
helm list -n envoy-gateway-system

# Get release details
helm status envoy-gateway -n envoy-gateway-system

# Get all release information
helm get all envoy-gateway -n envoy-gateway-system
```

### Step 5: Verify CRDs Were Installed

```powershell
# List Gateway API CRDs
kubectl get crd | Select-String "gateway"
```

**Expected CRDs:**

**Standard Gateway API CRDs:**
- `backendlbpolicies.gateway.networking.k8s.io`
- `backendtlspolicies.gateway.networking.k8s.io`
- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io`
- `grpcroutes.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`
- `referencegrants.gateway.networking.k8s.io`
- `tcproutes.gateway.networking.k8s.io`
- `tlsroutes.gateway.networking.k8s.io`
- `udproutes.gateway.networking.k8s.io`

**Envoy Gateway-specific CRDs:**
- `backends.gateway.envoyproxy.io`
- `backendtrafficpolicies.gateway.envoyproxy.io`
- `clienttrafficpolicies.gateway.envoyproxy.io`
- `envoyextensionpolicies.gateway.envoyproxy.io`
- `envoypatchpolicies.gateway.envoyproxy.io`
- `envoyproxies.gateway.envoyproxy.io`
- `httproutefilters.gateway.envoyproxy.io`
- `securitypolicies.gateway.envoyproxy.io`

---

## Verification

### Check Installation Health

```powershell
# 1. Check Envoy Gateway pod logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway --tail=50

# 2. Check for any errors
kubectl get events -n envoy-gateway-system --sort-by='.lastTimestamp'

# 3. Verify CRD installation
kubectl get crd envoyproxies.gateway.envoyproxy.io -o yaml | Select-String "version"

# 4. Test GatewayClass creation (from project manifests)
kubectl apply -f kubernetes/08-gateway-api/01-gatewayclass.yaml
kubectl get gatewayclass
```

**Expected GatewayClass output:**

```
NAME             CONTROLLER                                      ACCEPTED   AGE
envoy-gateway    gateway.envoyproxy.io/gatewayclass-controller   True       10s
```

---

## Troubleshooting

### Issue: Helm Install Fails with "conflict occurred"

**Symptom:**

```
Error: INSTALLATION FAILED: failed to install CRD crds/gatewayapi-crds.yaml: 
conflict occurred while applying object /httproutes.gateway.networking.k8s.io
```

**Cause:** Existing Gateway API CRDs from previous kubectl apply or another installation.

**Solution:**

```powershell
# Delete all existing Gateway CRDs
kubectl delete crd $(kubectl get crd -o name | Select-String "gateway") --ignore-not-found=true

# Retry Helm install
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.6.0 `
  --create-namespace `
  --namespace envoy-gateway-system
```

### Issue: Envoy Gateway Pod Not Starting

**Symptom:** Pod stuck in Pending, CrashLoopBackOff, or ImagePullBackOff

**Solution:**

```powershell
# Check pod status
kubectl describe pod -n envoy-gateway-system -l control-plane=envoy-gateway

# Check logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway --tail=100

# Common causes:
# 1. Insufficient resources - increase Docker Desktop memory (Settings > Resources > Memory: 4GB+)
# 2. Port conflicts - ensure no other gateway is running
# 3. Network issues - verify Docker Desktop networking is healthy
```

### Issue: CRDs Not Found After Install

**Symptom:** `kubectl get crd | grep gateway` returns no results

**Solution:**

```powershell
# Check if Helm release exists
helm list -n envoy-gateway-system

# If release exists but CRDs missing, uninstall and reinstall
helm uninstall envoy-gateway -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
# Wait 30 seconds
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.6.0 `
  --create-namespace `
  --namespace envoy-gateway-system
```

### Issue: Helm Version Compatibility

**Symptom:** `helm install` fails with parsing errors

**Cause:** Using Helm 2.x instead of Helm 3.x

**Solution:**

```powershell
# Check Helm version
helm version

# Expected: version.BuildInfo{Version:"v3.x.x", ...}

# If version is 2.x, upgrade to Helm 3
# Windows
winget install Helm.Helm

# macOS
brew upgrade helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Uninstallation

### Clean Uninstall (Recommended)

```powershell
# 1. Delete any Gateway resources in application namespaces first
kubectl delete gateway --all -n api-gateway-poc
kubectl delete httproute --all -n api-gateway-poc
kubectl delete securitypolicy --all -n api-gateway-poc
kubectl delete gatewayclass --all

# 2. Uninstall Helm release
helm uninstall envoy-gateway -n envoy-gateway-system

# 3. Delete the namespace
kubectl delete namespace envoy-gateway-system

# 4. (Optional) Delete Gateway API CRDs if you want complete removal
kubectl delete crd $(kubectl get crd -o name | Select-String "gateway")
```

### Verify Uninstallation

```powershell
# Check Helm releases (should be empty)
helm list -n envoy-gateway-system

# Check namespace (should not exist)
kubectl get namespace envoy-gateway-system

# Check CRDs (optional - should be empty if you deleted them)
kubectl get crd | Select-String "gateway"
```

---

## Upgrading

### Upgrade Envoy Gateway to a New Version

```powershell
# Check current version
helm list -n envoy-gateway-system

# Upgrade to a new version (e.g., v1.7.0)
helm upgrade envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.7.0 `
  --namespace envoy-gateway-system

# Wait for upgrade to complete
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# Verify upgrade
helm list -n envoy-gateway-system
kubectl get pods -n envoy-gateway-system
```

### Rollback to Previous Version

```powershell
# Check release history
helm history envoy-gateway -n envoy-gateway-system

# Rollback to previous revision
helm rollback envoy-gateway -n envoy-gateway-system

# Or rollback to specific revision
helm rollback envoy-gateway 1 -n envoy-gateway-system

# Verify rollback
helm list -n envoy-gateway-system
```

---

## Customizing Installation with Values

### View Available Configuration Options

```powershell
# Show all configurable values
helm show values oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 > envoy-gateway-values.yaml

# Open in editor to review options
code envoy-gateway-values.yaml
```

### Install with Custom Values

```powershell
# Create custom values file
# custom-values.yaml
```

```yaml
# Example custom values
deployment:
  replicas: 2
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

config:
  envoyGateway:
    logging:
      level:
        default: info
```

```powershell
# Install with custom values
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm `
  --version v1.6.0 `
  --namespace envoy-gateway-system `
  --create-namespace `
  --values custom-values.yaml
```

---

## Reference

### Helm Release Information

```powershell
# List all Helm releases in all namespaces
helm list --all-namespaces

# Get release status
helm status envoy-gateway -n envoy-gateway-system

# Get release values (what was used during install)
helm get values envoy-gateway -n envoy-gateway-system

# Get release manifest (all generated Kubernetes resources)
helm get manifest envoy-gateway -n envoy-gateway-system

# Get release notes
helm get notes envoy-gateway -n envoy-gateway-system

# Get release history
helm history envoy-gateway -n envoy-gateway-system
```

### Envoy Gateway Versions

| Version | Release Date | Notes |
|---------|-------------|-------|
| v1.6.0  | Nov 2024    | Latest stable (recommended) |
| v1.5.0  | Oct 2024    | Previous stable |
| v1.2.0  | Jan 2024    | Older stable (kubectl issues with CRD size) |

**Recommendation:** Always use the latest stable version (v1.6.0+) via Helm.

### Useful Links

- **Envoy Gateway Helm Chart:** https://hub.docker.com/r/envoyproxy/gateway-helm
- **Envoy Gateway Documentation:** https://gateway.envoyproxy.io/
- **Envoy Gateway GitHub:** https://github.com/envoyproxy/gateway
- **Helm Documentation:** https://helm.sh/docs/
- **Gateway API Specification:** https://gateway-api.sigs.k8s.io/

---

## Integration with EnvoyK8SPOC

### After Installing Envoy Gateway

Once Envoy Gateway is installed via Helm, proceed with deploying the EnvoyK8SPOC Phase 3 resources:

```powershell
# 1. Verify Envoy Gateway is ready
kubectl get pods -n envoy-gateway-system

# 2. Build service images (if not already built)
cd D:\repos\EnvoyK8SPOC\scripts\powershell
.\build-images.ps1

# 3. Deploy Phase 3 resources
.\deploy-k8s-phase3.ps1

# 4. Verify deployment
.\verify-deployment.ps1

# 5. Test endpoints
.\test-endpoints.ps1
```

See [kubernetes-deployment.md](kubernetes-deployment.md) for complete Phase 3 deployment guide.

---

## Summary

**Installation Process:**

1. ✅ Install Helm (`winget install Helm.Helm`)
2. ✅ Clean up any existing Gateway CRDs
3. ✅ Install Envoy Gateway v1.6.0 via Helm OCI registry
4. ✅ Wait for deployment to be ready
5. ✅ Verify CRDs and pods
6. ✅ Deploy application Gateway resources

**Key Benefits:**

- Handles large CRDs without API server errors
- Tracks release versions for easy upgrades/rollbacks
- Official Envoy Gateway support
- Declarative configuration via values

**Maintenance:**

- Upgrade: `helm upgrade envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version <new-version>`
- Rollback: `helm rollback envoy-gateway -n envoy-gateway-system`
- Uninstall: `helm uninstall envoy-gateway -n envoy-gateway-system`

---

**Last Updated:** 2024-11-24  
**Envoy Gateway Version:** v1.6.0  
**Helm Version:** 3.16+  
**Status:** Production-ready ✅
