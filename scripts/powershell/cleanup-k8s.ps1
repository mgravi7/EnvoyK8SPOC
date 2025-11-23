# Cleanup EnvoyK8SPOC Kubernetes resources
# Removes all deployed resources from the cluster

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Cleaning up EnvoyK8SPOC" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Detect which phase is deployed
$phase2Envoy = kubectl get deployment envoy -n api-gateway-poc --ignore-not-found=true 2>$null
$phase3Gateway = kubectl get gateway -n api-gateway-poc --ignore-not-found=true 2>$null

if ($phase3Gateway) {
    $deployedPhase = "Phase 3 (Gateway API)"
} elseif ($phase2Envoy) {
    $deployedPhase = "Phase 2 (Direct Envoy)"
} else {
    $deployedPhase = "Unknown or not deployed"
}

Write-Host ""
Write-Host "Detected deployment: $deployedPhase" -ForegroundColor Yellow
Write-Host ""
Write-Host "WARNING: This will delete all resources" -ForegroundColor Red

if ($phase3Gateway) {
    Write-Host "- Phase 3: Gateway API resources from api-gateway-poc" -ForegroundColor Yellow
    Write-Host "- Phase 3: Envoy proxy pods from envoy-gateway-system" -ForegroundColor Yellow
    Write-Host "- All backend services (Redis, Keycloak, authz-service, etc.)" -ForegroundColor Yellow
} elseif ($phase2Envoy) {
    Write-Host "- Phase 2: Envoy Deployment from api-gateway-poc" -ForegroundColor Yellow
    Write-Host "- All backend services (Redis, Keycloak, authz-service, etc.)" -ForegroundColor Yellow
} else {
    Write-Host "- All resources in namespace: api-gateway-poc" -ForegroundColor Yellow
}

Write-Host ""
$response = Read-Host "Continue? (y/N)"

if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

if ($phase3Gateway) {
    Write-Host "Step 1: Deleting Phase 3 Gateway API resources..." -ForegroundColor Cyan
    
    # Delete SecurityPolicies first (they reference HTTPRoutes/Gateway)
    Write-Host "- Deleting SecurityPolicies..." -ForegroundColor Yellow
    kubectl delete securitypolicy --all -n api-gateway-poc --ignore-not-found=true
    
    # Delete HTTPRoutes (they reference Gateway)
    Write-Host "- Deleting HTTPRoutes..." -ForegroundColor Yellow
    kubectl delete httproute --all -n api-gateway-poc --ignore-not-found=true
    
    # Delete Gateway (this will trigger Envoy proxy deletion)
    Write-Host "- Deleting Gateway..." -ForegroundColor Yellow
    kubectl delete gateway --all -n api-gateway-poc --ignore-not-found=true
    
    # Delete GatewayClass
    Write-Host "- Deleting GatewayClass..." -ForegroundColor Yellow
    kubectl delete gatewayclass envoy-gateway --ignore-not-found=true
    
    Write-Host ""
    Write-Host "Waiting for Envoy proxy pod to terminate..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
} elseif ($phase2Envoy) {
    Write-Host "Step 1: Deleting Phase 2 Envoy resources..." -ForegroundColor Cyan
    kubectl delete -f ../../kubernetes/07-envoy-gateway --ignore-not-found=true
}

Write-Host ""
Write-Host "Step 2: Deleting namespace and all backend services..." -ForegroundColor Cyan
kubectl delete namespace api-gateway-poc --ignore-not-found=true

Write-Host ""
Write-Host "Waiting for namespace to be fully deleted..." -ForegroundColor Yellow

# Wait for namespace deletion (timeout after 60 seconds)
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $ns = kubectl get namespace api-gateway-poc --ignore-not-found=true 2>$null
    if (-not $ns) {
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "." -NoNewline
}
Write-Host ""

if ($phase3Gateway) {
    Write-Host ""
    Write-Host "Phase 3 Cleanup:" -ForegroundColor Cyan
    Write-Host "The Envoy Gateway operator is still running in envoy-gateway-system namespace." -ForegroundColor Yellow
    Write-Host "It can be reused for future Phase 3 deployments." -ForegroundColor Yellow
    Write-Host ""
    $deleteOperator = Read-Host "Do you want to delete the Envoy Gateway operator? (y/N)"
    
    if ($deleteOperator -eq 'y' -or $deleteOperator -eq 'Y') {
        Write-Host ""
        Write-Host "Deleting Envoy Gateway operator..." -ForegroundColor Yellow
        kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml --ignore-not-found=true
        
        Write-Host ""
        Write-Host "Waiting for envoy-gateway-system namespace to be deleted..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        Write-Host "Envoy Gateway operator deleted." -ForegroundColor Green
    } else {
        Write-Host "Envoy Gateway operator kept (recommended for reuse)." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Cleanup Complete" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "All resources have been removed." -ForegroundColor White
Write-Host ""
Write-Host "To redeploy Phase 2:" -ForegroundColor White
Write-Host "  .\deploy-k8s-phase2.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "To redeploy Phase 3:" -ForegroundColor White
if ($phase3Gateway -and ($deleteOperator -ne 'y' -and $deleteOperator -ne 'Y')) {
    Write-Host "  .\deploy-k8s-phase3.ps1 (Envoy Gateway already installed)" -ForegroundColor Gray
} else {
    Write-Host "  1. Install Envoy Gateway first:" -ForegroundColor Gray
    Write-Host "     kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml" -ForegroundColor Gray
    Write-Host "  2. Deploy Phase 3:" -ForegroundColor Gray
    Write-Host "     .\deploy-k8s-phase3.ps1" -ForegroundColor Gray
}
Write-Host ""
Write-Host "To rebuild images:" -ForegroundColor White
Write-Host "  .\build-images.ps1" -ForegroundColor Gray
