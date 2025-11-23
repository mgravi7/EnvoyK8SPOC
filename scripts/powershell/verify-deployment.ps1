# Verify EnvoyK8SPOC deployment (Phase 2 or Phase 3)
# Checks pod status, service endpoints, and component health

$ErrorActionPreference = "Stop"
$Namespace = "api-gateway-poc"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verifying Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Detect which phase is deployed
$phase2Envoy = kubectl get deployment envoy -n $Namespace --ignore-not-found=true 2>$null
$phase3Gateway = kubectl get gateway -n $Namespace --ignore-not-found=true 2>$null

if ($phase3Gateway) {
    $deploymentPhase = "Phase 3 (Gateway API)"
} elseif ($phase2Envoy) {
    $deploymentPhase = "Phase 2 (Direct Envoy)"
} else {
    $deploymentPhase = "Unknown (no gateway detected)"
}

Write-Host "Detected: $deploymentPhase" -ForegroundColor Yellow

Write-Host ""
Write-Host "1. Checking namespace..." -ForegroundColor Yellow
kubectl get namespace $Namespace

Write-Host ""
Write-Host "2. Checking all pods..." -ForegroundColor Yellow
kubectl get pods -n $Namespace -o wide

Write-Host ""
Write-Host "3. Checking pod status details..." -ForegroundColor Yellow
$pods = kubectl get pods -n $Namespace --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
$notRunningCount = 0
foreach ($pod in $pods) {
    $status = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.phase}' 2>$null
    if ($status -ne "Running") {
        $notRunningCount++
        Write-Host "WARNING: Pod $pod is in $status state" -ForegroundColor Red
        Write-Host "Recent events:"
        kubectl describe pod $pod -n $Namespace | Select-Object -Last 20
    }
}
if ($notRunningCount -eq 0) {
    Write-Host "All pods are Running." -ForegroundColor Green
}

Write-Host ""
Write-Host "4. Checking services..." -ForegroundColor Yellow
kubectl get svc -n $Namespace

Write-Host ""
Write-Host "5. Checking endpoints..." -ForegroundColor Yellow
# Prefer EndpointSlices (newer API); fall back to Endpoints for older clusters
try {
    $epSlices = kubectl get endpointslices -n $Namespace -o wide 2>$null
    if ($epSlices) {
        Write-Host "EndpointSlices:" -ForegroundColor Cyan
        kubectl get endpointslices -n $Namespace -o wide
    } else {
        throw "no endpointslices"
    }
} catch {
    Write-Host "(EndpointSlice not available; showing Endpoints)" -ForegroundColor Yellow
    # Suppress kubectl deprecation warning by capturing stderr and filtering
    $endpointsRaw = kubectl get endpoints -n $Namespace 2>&1 | Where-Object { $_ -notmatch "Warning: v1 Endpoints is deprecated" }
    $endpointsRaw | ForEach-Object { Write-Host $_ }
}

Write-Host ""
Write-Host "6. Checking ConfigMaps..." -ForegroundColor Yellow
kubectl get configmap -n $Namespace

Write-Host ""
Write-Host "7. Checking Secrets..." -ForegroundColor Yellow
kubectl get secret -n $Namespace

Write-Host ""
Write-Host "8. Checking PVC..." -ForegroundColor Yellow
kubectl get pvc -n $Namespace

if ($phase3Gateway) {
    Write-Host ""
    Write-Host "9. Checking Gateway API resources (Phase 3)..." -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "Gateway:" -ForegroundColor Cyan
    kubectl get gateway -n $Namespace
    Write-Host ""
    kubectl describe gateway -n $Namespace | Select-String -Pattern "Status:" -Context 0,10
    
    Write-Host ""
    Write-Host "HTTPRoutes:" -ForegroundColor Cyan
    kubectl get httproute -n $Namespace
    
    Write-Host ""
    Write-Host "SecurityPolicies:" -ForegroundColor Cyan
    kubectl get securitypolicy -n $Namespace
    
    Write-Host ""
    Write-Host "GatewayClass:" -ForegroundColor Cyan
    kubectl get gatewayclass envoy-gateway 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "GatewayClass not found" }
}

Write-Host ""
Write-Host "10. Checking recent logs for each service..." -ForegroundColor Yellow

Write-Host ""
Write-Host "Redis logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/redis --tail=10 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }

Write-Host ""
Write-Host "Keycloak logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/keycloak --tail=10 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }

Write-Host ""
Write-Host "AuthZ Service logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/authz-service --tail=10 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }

Write-Host ""
Write-Host "Customer Service logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/customer-service --tail=10 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }

Write-Host ""
Write-Host "Product Service logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/product-service --tail=10 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }

if ($phase2Envoy) {
    Write-Host ""
    Write-Host "Envoy logs (last 10 lines) - Phase 2:" -ForegroundColor Cyan
    kubectl logs -n $Namespace deployment/envoy --tail=10 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }
}

if ($phase3Gateway) {
    Write-Host ""
    Write-Host "Gateway Envoy Proxy logs (last 50 lines) - Phase 3:" -ForegroundColor Cyan
    # Envoy Gateway deploys the proxy in envoy-gateway-system namespace
    try {
        # Ensure proxy pods exist first
        $proxyPods = kubectl get pods -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=api-gateway" --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
        if (-not $proxyPods) {
            Write-Host "No Envoy proxy pods found in envoy-gateway-system" -ForegroundColor Yellow
        } else {
            # Request logs from the envoy container specifically to avoid "Defaulted container" messages
            $proxyLogs = kubectl logs -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=api-gateway" -c envoy --tail=50 2>&1
            if ($proxyLogs) {
                $proxyLogs | ForEach-Object { Write-Host $_ }
                if ($proxyLogs -match "jwks" -or $proxyLogs -match "JWKS" -or $proxyLogs -match "pubkey") {
                    Write-Host "`nWARNING: JWKS fetch issues detected in Envoy logs. This usually means Keycloak service endpoints were not ready when SecurityPolicies were applied. Consider re-running the deploy or ensuring Keycloak endpoints are available before applying SecurityPolicies." -ForegroundColor Yellow
                }
            } else {
                Write-Host "No logs available" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "No logs available" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$runningPods = (kubectl get pods -n $Namespace --no-headers 2>$null | Select-String "Running").Count
$totalPods = (kubectl get pods -n $Namespace --no-headers 2>$null).Count

Write-Host "Deployment Phase: $deploymentPhase" -ForegroundColor White
Write-Host "Pods running: $runningPods / $totalPods" -ForegroundColor White

if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
    Write-Host "Status: All pods are running!" -ForegroundColor Green
} else {
    Write-Host "Status: Some pods are not running. Check logs above." -ForegroundColor Red
}

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  kubectl describe pod <pod-name> -n $Namespace" -ForegroundColor White
Write-Host "  kubectl logs -f deployment/<deployment-name> -n $Namespace" -ForegroundColor White

if ($phase3Gateway) {
    Write-Host "  kubectl describe gateway api-gateway -n $Namespace" -ForegroundColor White
    Write-Host "  kubectl logs -n $Namespace -l gateway.envoyproxy.io/owning-gateway-name=api-gateway" -ForegroundColor White
}
