# Verify EnvoyK8SPOC deployment (Phase 3 only)
# Checks pod status, service endpoints, and component health

$ErrorActionPreference = "Stop"
$Namespace = "api-gateway-poc"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verifying Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Write-Host "Detected: Phase 3 (Gateway API)" -ForegroundColor Yellow

Write-Host "1. Checking namespace..." -ForegroundColor Yellow
kubectl get namespace $Namespace

Write-Host "2. Checking all pods..." -ForegroundColor Yellow
kubectl get pods -n $Namespace -o wide

Write-Host "3. Checking pod status details..." -ForegroundColor Yellow
$notRunningCount = 0
$pods = kubectl get pods -n $Namespace --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
foreach ($pod in $pods) {
    $status = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.phase}' 2>$null
    if ($status -ne "Running") {
        $notRunningCount++
        Write-Host "WARNING: Pod $pod is in $status state" -ForegroundColor Red
        Write-Host "Recent events:"
        kubectl describe pod $pod -n $Namespace | Select-Object -Last 20
    }
}
if ($notRunningCount -eq 0) { Write-Host "All pods are Running." -ForegroundColor Green }

Write-Host "4. Checking services..." -ForegroundColor Yellow
kubectl get svc -n $Namespace

Write-Host "5. Checking endpoints..." -ForegroundColor Yellow
try { kubectl get endpointslices -n $Namespace -o wide } catch { Write-Host "(EndpointSlice not available; showing Endpoints)"; kubectl get endpoints -n $Namespace 2>&1 | Where-Object { $_ -notmatch "Warning: v1 Endpoints is deprecated" } }

Write-Host "6. Checking ConfigMaps..." -ForegroundColor Yellow
kubectl get configmap -n $Namespace

Write-Host "7. Checking Secrets..." -ForegroundColor Yellow
kubectl get secret -n $Namespace

Write-Host "8. Checking PVC..." -ForegroundColor Yellow
kubectl get pvc -n $Namespace

Write-Host "9. Checking Gateway API resources..." -ForegroundColor Yellow
Write-Host "Gateway:" -ForegroundColor Cyan
kubectl get gateway -n $Namespace
Write-Host "HTTPRoutes:" -ForegroundColor Cyan
kubectl get httproute -n $Namespace
Write-Host "SecurityPolicies:" -ForegroundColor Cyan
kubectl get securitypolicy -n $Namespace
Write-Host "GatewayClass:" -ForegroundColor Cyan
# kubectl is an external command; capture output and check exit code instead of shell-style ||
$gcResult = kubectl get gatewayclass envoy-gateway 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "GatewayClass not found" -ForegroundColor Yellow
} else {
    Write-Host $gcResult
}

Write-Host "10. Checking recent logs for each service..." -ForegroundColor Yellow

Write-Host "Redis logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/redis --tail=10 2>$null

Write-Host "Keycloak logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/keycloak --tail=10 2>$null

Write-Host "AuthZ Service logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/authz-service --tail=10 2>$null

Write-Host "Customer Service logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/customer-service --tail=10 2>$null

Write-Host "Product Service logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/product-service --tail=10 2>$null

Write-Host "Gateway Envoy Proxy logs (last 10 lines):" -ForegroundColor Cyan
$proxyPods = kubectl get pods -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=api-gateway" --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
if (-not $proxyPods) { Write-Host "No Envoy proxy pods found in envoy-gateway-system" -ForegroundColor Yellow } else { kubectl logs -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=api-gateway" -c envoy --tail=10 2>$null }

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$runningPods = (kubectl get pods -n $Namespace --no-headers 2>$null | Select-String "Running").Count
$totalPods = (kubectl get pods -n $Namespace --no-headers 2>$null).Count

Write-Host "Deployment Phase: Phase 3 (Gateway API)" -ForegroundColor White
Write-Host "Pods running: $runningPods / $totalPods" -ForegroundColor White

if ($runningPods -eq $totalPods -and $totalPods -gt 0) { Write-Host "Status: All pods are running!" -ForegroundColor Green } else { Write-Host "Status: Some pods are not running. Check logs above." -ForegroundColor Red }

Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  kubectl describe pod <pod-name> -n $Namespace" -ForegroundColor White
Write-Host "  kubectl logs -f deployment/<deployment-name> -n $Namespace" -ForegroundColor White
Write-Host "  kubectl describe gateway api-gateway -n $Namespace" -ForegroundColor White
Write-Host "  kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway" -ForegroundColor White
