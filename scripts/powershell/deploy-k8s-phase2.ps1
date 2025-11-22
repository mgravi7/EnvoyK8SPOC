# Deploy EnvoyK8SPOC Phase 2 to Kubernetes
# Applies all manifests in correct order with wait logic

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Deploying EnvoyK8SPOC Phase 2" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..") | Select-Object -ExpandProperty Path
$K8sDir = Join-Path $RepoRoot "kubernetes"

Set-Location $RepoRoot

# Function to wait for deployment
function Wait-ForDeployment {
    param(
        [string]$Namespace,
        [string]$Deployment,
        [int]$Timeout = 300
    )
    
    Write-Host "Waiting for deployment/$Deployment to be ready..." -ForegroundColor Yellow
    kubectl wait --for=condition=available --timeout="${Timeout}s" `
        deployment/$Deployment -n $Namespace
}

Write-Host ""
Write-Host "Step 1: Creating namespace..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "00-namespace\namespace.yaml")

Write-Host ""
Write-Host "Step 2: Creating ConfigMaps and Secrets..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "01-config\")

Write-Host ""
Write-Host "Step 3: Creating PersistentVolumeClaim for Redis..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "02-storage\redis-pvc.yaml")

Write-Host ""
Write-Host "Step 4: Deploying Redis..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "03-data\")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "redis" -Timeout 120

Write-Host ""
Write-Host "Step 5: Deploying Keycloak..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "04-iam\")
Write-Host "Note: Keycloak takes ~90 seconds to start. Waiting..." -ForegroundColor Yellow
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "keycloak" -Timeout 180

Write-Host ""
Write-Host "Step 6: Deploying Authorization Service..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "05-authz\")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "authz-service" -Timeout 120

Write-Host ""
Write-Host "Step 7: Deploying Backend Services..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "06-services\")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "customer-service" -Timeout 120
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "product-service" -Timeout 120

Write-Host ""
Write-Host "Step 8: Deploying Envoy Gateway..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "07-envoy-gateway\")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "envoy" -Timeout 120

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Checking pod status:"
kubectl get pods -n api-gateway-poc

Write-Host ""
Write-Host "Checking services:"
kubectl get svc -n api-gateway-poc

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "1. Wait for LoadBalancer IPs to be assigned (may take a minute)"
Write-Host "2. Run: .\verify-deployment.ps1 to check all components"
Write-Host "3. Run: .\test-endpoints.ps1 to test service endpoints"
Write-Host "4. Access services:"
Write-Host "   - Keycloak: http://localhost:8180"
Write-Host "   - Envoy Gateway: http://localhost:8080"
Write-Host "   - Envoy Admin: http://localhost:9901"
