# Clean up all EnvoyK8SPOC resources from Kubernetes
# Handles both Phase 2 and Phase 3 deployments

$ErrorActionPreference = "Stop"
$Namespace = "api-gateway-poc"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Cleaning up EnvoyK8SPOC" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "WARNING: This will delete all resources in namespace: $Namespace" -ForegroundColor Red
Write-Host "This includes:" -ForegroundColor Yellow
Write-Host "  - Phase 2: Envoy Deployment, ConfigMap, Service" -ForegroundColor White
Write-Host "  - Phase 3: Gateway, HTTPRoutes, SecurityPolicies, GatewayClass" -ForegroundColor White
Write-Host "  - All backend services (Redis, Keycloak, authz-service, etc.)" -ForegroundColor White
Write-Host ""
$response = Read-Host "Continue? (y/N)"

if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Step 1: Deleting Phase 3 Gateway API resources (if present)..." -ForegroundColor Yellow
kubectl delete securitypolicy --all -n $Namespace --ignore-not-found=true 2>$null
kubectl delete httproute --all -n $Namespace --ignore-not-found=true 2>$null
kubectl delete gateway --all -n $Namespace --ignore-not-found=true 2>$null
kubectl delete gatewayclass envoy-gateway --ignore-not-found=true 2>$null

Write-Host ""
Write-Host "Step 2: Deleting namespace and all resources..." -ForegroundColor Yellow
kubectl delete namespace $Namespace

Write-Host ""
Write-Host "Waiting for namespace to be fully deleted..." -ForegroundColor Yellow
kubectl wait --for=delete namespace/$Namespace --timeout=60s 2>$null

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Cleanup Complete" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "All resources have been removed." -ForegroundColor White
Write-Host ""
Write-Host "To redeploy Phase 2:" -ForegroundColor Cyan
Write-Host "  .\deploy-k8s-phase2.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To redeploy Phase 3:" -ForegroundColor Cyan
Write-Host "  .\deploy-k8s-phase3.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To rebuild images:" -ForegroundColor Cyan
Write-Host "  .\build-images.ps1" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Envoy Gateway operator (envoy-gateway-system) was NOT deleted." -ForegroundColor Yellow
Write-Host "      It can be reused for future Phase 3 deployments." -ForegroundColor Yellow
Write-Host "      To uninstall Envoy Gateway:" -ForegroundColor Yellow
Write-Host "      kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml" -ForegroundColor Gray
