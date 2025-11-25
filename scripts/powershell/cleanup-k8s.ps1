# Cleanup EnvoyK8SPOC Kubernetes resources (Phase 3 only)
# Removes Phase 3 deployed resources from the cluster

$ErrorActionPreference = "Stop"
$Namespace = "api-gateway-poc"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Cleaning up EnvoyK8SPOC (Gateway API)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$response = Read-Host "This will delete all resources in namespace $Namespace. Continue? (y/N)"
if ($response -ne 'y' -and $response -ne 'Y') { Write-Host "Cleanup cancelled."; exit 0 }

Write-Host "Step 1: Deleting SecurityPolicies, HTTPRoutes, and Gateway..." -ForegroundColor Yellow
kubectl delete securitypolicy --all -n $Namespace --ignore-not-found=true | Out-Null
kubectl delete httproute --all -n $Namespace --ignore-not-found=true | Out-Null
kubectl delete gateway --all -n $Namespace --ignore-not-found=true | Out-Null
kubectl delete gatewayclass envoy-gateway --ignore-not-found=true | Out-Null

Write-Host "Waiting for Envoy proxy pods to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Step 2: Deleting namespace and all backend services..." -ForegroundColor Yellow
kubectl delete namespace $Namespace --ignore-not-found=true | Out-Null

Write-Host "Waiting for namespace to be fully deleted..." -ForegroundColor Yellow
$timeout = 60; $elapsed = 0
while ($elapsed -lt $timeout) {
    $ns = kubectl get namespace $Namespace --ignore-not-found=true 2>$null
    if (-not $ns) { break }
    Start-Sleep -Seconds 2; $elapsed += 2; Write-Host -NoNewline "."
}
Write-Host ""; Write-Host "Cleanup complete. Envoy Gateway operator (envoy-gateway-system) is left intact for reuse." -ForegroundColor Green
