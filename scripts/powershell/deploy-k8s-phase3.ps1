# Deploy EnvoyK8SPOC Phase 3 to Kubernetes using Gateway API
# This script deploys backend services + Gateway API resources (NOT Phase 2 Envoy)

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Deploying EnvoyK8SPOC Phase 3" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get script directory and paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
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
    # Use call operator with explicit arguments to avoid line continuation/backtick issues
    & "kubectl" "wait" "--for=condition=available" "--timeout=${Timeout}s" "deployment/$Deployment" "-n" "$Namespace"
}

# Function to wait for Gateway
function Wait-ForGateway {
    param(
        [string]$Namespace,
        [string]$Gateway,
        [int]$Timeout = 300
    )
    
    Write-Host "Waiting for gateway/$Gateway to be ready..." -ForegroundColor Yellow
    $timeoutEnd = (Get-Date).AddSeconds($Timeout)
    
    while ((Get-Date) -lt $timeoutEnd) {
        try {
            $status = kubectl get gateway $Gateway -n $Namespace -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>$null
            if ($status -eq "True") {
                Write-Host "Gateway $Gateway is ready!" -ForegroundColor Green
                return $true
            }
            Write-Host "Gateway status: $status - waiting..." -ForegroundColor Yellow
        } catch {
            Write-Host "Gateway status: Unknown - waiting..." -ForegroundColor Yellow
        }
        Start-Sleep -Seconds 5
    }
    
    Write-Host "Warning: Gateway did not become ready within ${Timeout}s" -ForegroundColor Yellow
    return $false
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 0: Pre-flight Checks" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if Envoy Gateway is installed
Write-Host "Checking if Envoy Gateway is installed..." -ForegroundColor Yellow
$envoyGatewayNs = kubectl get namespace envoy-gateway-system --ignore-not-found=true 2>$null
if (-not $envoyGatewayNs) {
    Write-Host ""
    Write-Host "ERROR: Envoy Gateway is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Envoy Gateway first:" -ForegroundColor Yellow
    Write-Host "  kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml" -ForegroundColor White
    Write-Host "  kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available" -ForegroundColor White
    Write-Host ""
    Write-Host "Or refer to: kubernetes/08-gateway-api/00-install-envoy-gateway.yaml" -ForegroundColor White
    exit 1
}

# Verify Envoy Gateway is running
try {
    kubectl wait --timeout=10s -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available 2>$null | Out-Null
} catch {
    Write-Host "Warning: Envoy Gateway deployment is not ready. Continuing anyway..." -ForegroundColor Yellow
}

Write-Host "Envoy Gateway is installed" -ForegroundColor Green

# Check if Phase 2 Envoy is running
$phase2Envoy = kubectl get deployment envoy -n api-gateway-poc --ignore-not-found=true 2>$null
if ($phase2Envoy) {
    Write-Host ""
    Write-Host "WARNING: Phase 2 Envoy deployment is still running!" -ForegroundColor Yellow
    Write-Host "Phase 3 and Phase 2 cannot run simultaneously (port conflicts)." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to delete Phase 2 Envoy resources? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Deleting Phase 2 Envoy resources..." -ForegroundColor Yellow
        kubectl delete -f (Join-Path $K8sDir "07-envoy-gateway") --ignore-not-found=true
        Write-Host "Phase 2 Envoy resources deleted." -ForegroundColor Green
    } else {
        Write-Host "Please manually delete Phase 2 Envoy before proceeding:" -ForegroundColor Yellow
        Write-Host "  kubectl delete -f kubernetes/07-envoy-gateway/" -ForegroundColor White
        exit 1
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 1: Creating namespace" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "00-namespace\namespace.yaml")

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 2: Creating ConfigMaps and Secrets" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "01-config")

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 3: Creating PersistentVolumeClaim" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "02-storage\redis-pvc.yaml")

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 4: Deploying Redis" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "03-data")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "redis" -Timeout 120

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 5: Deploying Keycloak" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "04-iam")
Write-Host "Note: Keycloak takes ~90 seconds to start. Waiting..." -ForegroundColor Yellow
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "keycloak" -Timeout 180

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 6: Deploying Authorization Service" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "05-authz")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "authz-service" -Timeout 120

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 7: Deploying Backend Services" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "06-services")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "customer-service" -Timeout 120
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "product-service" -Timeout 120

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 8: Deploying Gateway API Resources" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "Creating GatewayClass..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\01-gatewayclass.yaml")

Write-Host "Creating Gateway..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\02-gateway.yaml")
Wait-ForGateway -Namespace "api-gateway-poc" -Gateway "api-gateway" -Timeout 180

Write-Host "Creating HTTPRoutes..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\03-httproute-customer.yaml")
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\04-httproute-product.yaml")
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\05-httproute-auth-me.yaml")
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\06-httproute-keycloak.yaml")

Write-Host "Applying Security Policies..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\07-securitypolicy-jwt.yaml")
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\08-securitypolicy-extauth.yaml")

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backend Services:" -ForegroundColor Cyan
kubectl get pods -n api-gateway-poc | Select-String -Pattern "(redis|keycloak|authz|customer|product)"

Write-Host ""
Write-Host "Gateway API Resources:" -ForegroundColor Cyan
Write-Host "Gateway:" -ForegroundColor Yellow
kubectl get gateway -n api-gateway-poc
Write-Host ""
Write-Host "HTTPRoutes:" -ForegroundColor Yellow
kubectl get httproute -n api-gateway-poc

Write-Host ""
Write-Host "SecurityPolicies:" -ForegroundColor Yellow
kubectl get securitypolicy -n api-gateway-poc

Write-Host ""
Write-Host "Gateway Service (LoadBalancer):" -ForegroundColor Cyan
# Use call operator & with argument array to avoid any quoting/parsing issues
& "kubectl" "get" "svc" "-n" "api-gateway-poc" "-l" "gateway.envoyproxy.io/owning-gateway-name=api-gateway"

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "1. Wait for LoadBalancer IP to be assigned (may take a minute)" -ForegroundColor White
Write-Host "2. Run: .\verify-deployment.ps1 to check all components" -ForegroundColor White
Write-Host "3. Run: .\test-endpoints.ps1 to test service endpoints" -ForegroundColor White
Write-Host "4. Access services:" -ForegroundColor White
Write-Host "   - API Gateway: http://localhost:8080" -ForegroundColor White
Write-Host "   - Keycloak: http://localhost:8080/auth" -ForegroundColor White
Write-Host ""
Write-Host "5. Check Gateway status:" -ForegroundColor White
Write-Host "   kubectl describe gateway api-gateway -n api-gateway-poc" -ForegroundColor Gray
Write-Host ""
Write-Host "6. View Envoy proxy logs:" -ForegroundColor White
Write-Host "   Example:" -ForegroundColor Gray
Write-Host "   (run the following command in your shell)" -ForegroundColor Gray
Write-Host ""
Write-Host "   kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway" -ForegroundColor Gray

# End of script
