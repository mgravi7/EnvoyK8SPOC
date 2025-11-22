# Verify EnvoyK8SPOC Phase 2 deployment
# Checks pod status, service endpoints, and component health

$ErrorActionPreference = "Stop"
$Namespace = "api-gateway-poc"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verifying Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "1. Checking namespace..." -ForegroundColor Yellow
kubectl get namespace $Namespace

Write-Host ""
Write-Host "2. Checking all pods..." -ForegroundColor Yellow
kubectl get pods -n $Namespace -o wide

Write-Host ""
Write-Host "3. Checking pod status details..." -ForegroundColor Yellow
$pods = kubectl get pods -n $Namespace --no-headers | ForEach-Object { ($_ -split '\s+')[0] }
foreach ($pod in $pods) {
    $status = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.phase}'
    if ($status -ne "Running") {
        Write-Host "WARNING: Pod $pod is in $status state" -ForegroundColor Red
        Write-Host "Recent events:"
        kubectl describe pod $pod -n $Namespace | Select-Object -Last 20
    }
}

Write-Host ""
Write-Host "4. Checking services..." -ForegroundColor Yellow
kubectl get svc -n $Namespace

Write-Host ""
Write-Host "5. Checking endpoints..." -ForegroundColor Yellow
kubectl get endpoints -n $Namespace

Write-Host ""
Write-Host "6. Checking ConfigMaps..." -ForegroundColor Yellow
kubectl get configmap -n $Namespace

Write-Host ""
Write-Host "7. Checking Secrets..." -ForegroundColor Yellow
kubectl get secret -n $Namespace

Write-Host ""
Write-Host "8. Checking PVC..." -ForegroundColor Yellow
kubectl get pvc -n $Namespace

Write-Host ""
Write-Host "9. Checking recent logs for each service..." -ForegroundColor Yellow

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

Write-Host ""
Write-Host "Envoy logs (last 10 lines):" -ForegroundColor Cyan
kubectl logs -n $Namespace deployment/envoy --tail=10 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No logs available" }

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$runningPods = (kubectl get pods -n $Namespace --no-headers | Select-String "Running").Count
$totalPods = (kubectl get pods -n $Namespace --no-headers).Count

Write-Host "Pods running: $runningPods / $totalPods"

if ($runningPods -eq $totalPods) {
    Write-Host "Status: All pods are running!" -ForegroundColor Green
} else {
    Write-Host "Status: Some pods are not running. Check logs above." -ForegroundColor Red
}

Write-Host ""
Write-Host "To check detailed pod status:"
Write-Host "  kubectl describe pod <pod-name> -n $Namespace"
Write-Host ""
Write-Host "To view full logs:"
Write-Host "  kubectl logs -f deployment/<deployment-name> -n $Namespace"
