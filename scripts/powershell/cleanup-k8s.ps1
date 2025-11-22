# Clean up all EnvoyK8SPOC Phase 2 resources from Kubernetes

$ErrorActionPreference = "Stop"
$Namespace = "api-gateway-poc"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Cleaning up EnvoyK8SPOC Phase 2" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "WARNING: This will delete all resources in namespace: $Namespace" -ForegroundColor Red
$response = Read-Host "Continue? (y/N)"

if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Deleting namespace and all resources..." -ForegroundColor Yellow
kubectl delete namespace $Namespace

Write-Host ""
Write-Host "Waiting for namespace to be fully deleted..." -ForegroundColor Yellow
kubectl wait --for=delete namespace/$Namespace --timeout=60s 2>$null

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Cleanup Complete" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "All resources have been removed."
Write-Host ""
Write-Host "To redeploy:"
Write-Host "  .\deploy-k8s-phase2.ps1"
Write-Host ""
Write-Host "To rebuild images:"
Write-Host "  .\build-images.ps1"
