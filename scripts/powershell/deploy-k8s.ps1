# Deploy EnvoyK8SPOC to Kubernetes using Gateway API (Phase 3 only)
# This script deploys backend services + Gateway API resources

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Deploying EnvoyK8SPOC (Gateway API)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get script directory and paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$K8sDir = Join-Path $RepoRoot "kubernetes"

Set-Location $RepoRoot

function Wait-ForDeployment {
    param(
        [string]$Namespace,
        [string]$Deployment,
        [int]$Timeout = 300
    )
    Write-Host "Waiting for deployment/$Deployment to be ready..." -ForegroundColor Yellow
    & kubectl wait --for=condition=available --timeout=${Timeout}s deployment/$Deployment -n $Namespace
}

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
            $status = kubectl get gateway $Gateway -n $Namespace -o jsonpath="{.status.conditions[?(@.type=='Programmed')].status}" 2>$null
            if ($status -eq "True") { Write-Host "Gateway $Gateway is ready!" -ForegroundColor Green; return $true }
            try {
                $proxyReady = kubectl get pods -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=$Gateway" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>$null
                if ($proxyReady -match 'true') { Write-Host "Envoy proxy pod for $Gateway is ready!" -ForegroundColor Green; return $true }
            } catch {}
            Write-Host "Gateway status: $status - waiting..." -ForegroundColor Yellow
        } catch { Write-Host "Gateway status: Unknown - waiting..." -ForegroundColor Yellow }
        Start-Sleep -Seconds 5
    }
    Write-Host "Warning: Gateway did not become ready within ${Timeout}s" -ForegroundColor Yellow
    kubectl get pods -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=$Gateway" -o wide 2>$null
    kubectl logs -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=$Gateway" --tail=50 2>&1 | ForEach-Object { Write-Host $_ }
    return $false
}

function Wait-ForServiceEndpoint {
    param(
        [string]$Namespace,
        [string]$Service,
        [int]$Timeout = 120
    )
    Write-Host "Waiting for service endpoint $Service in namespace $Namespace..." -ForegroundColor Yellow
    $timeoutEnd = (Get-Date).AddSeconds($Timeout)
    while ((Get-Date) -lt $timeoutEnd) {
        try { $rawips = kubectl get endpointslices -n $Namespace -l "kubernetes.io/service-name=$Service" -o jsonpath="{.items[*].endpoints[*].addresses[*]}" 2>$null } catch { $rawips = $null }
        if (-not $rawips) { try { $rawips = kubectl get endpoints $Service -n $Namespace -o jsonpath="{.subsets[*].addresses[*].ip}" 2>$null } catch { $rawips = $null } }
        $ips = if ($rawips) { $rawips.ToString().Trim() } else { "" }
        Write-Host "endpoints='$ips'" -ForegroundColor DarkGray
        if (-not [string]::IsNullOrWhiteSpace($ips) -and $ips -match '\d+\.\d+\.\d+\.\d+') { Write-Host "Service $Service has endpoints: $ips" -ForegroundColor Green; return $true }
        Start-Sleep -Seconds 5
    }
    Write-Host "Warning: Service $Service did not have endpoints within ${Timeout}s" -ForegroundColor Yellow
    kubectl get endpoints $Service -n $Namespace -o yaml 2>&1 | ForEach-Object { Write-Host $_ }
    kubectl get endpointslices -n $Namespace -l "kubernetes.io/service-name=$Service" -o yaml 2>&1 | ForEach-Object { Write-Host $_ }
    kubectl describe pod -l app=keycloak -n $Namespace 2>&1 | ForEach-Object { Write-Host $_ }
    kubectl get events -n $Namespace --sort-by='.lastTimestamp' | Select-Object -Last 50 | ForEach-Object { Write-Host $_ }
    return $false
}

Write-Host "";
Write-Host "Checking if Envoy Gateway is installed..." -ForegroundColor Yellow
if (-not (kubectl get namespace envoy-gateway-system --ignore-not-found=true 2>$null)) {
    Write-Host "ERROR: Envoy Gateway is not installed!" -ForegroundColor Red
    Write-Host "Please install Envoy Gateway via Helm (recommended):" -ForegroundColor Yellow
    Write-Host "  helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 --create-namespace --namespace envoy-gateway-system" -ForegroundColor White
    Write-Host "  kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available" -ForegroundColor White
    exit 1
}

try { kubectl wait --timeout=10s -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available | Out-Null } catch { Write-Host "Warning: Envoy Gateway deployment is not ready. Continuing anyway..." -ForegroundColor Yellow }
Write-Host "Envoy Gateway is installed" -ForegroundColor Green

Write-Host "\nStep 1: Creating namespace" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "00-namespace\namespace.yaml")

Write-Host "\nStep 2: Creating ConfigMaps and Secrets" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "01-config")

Write-Host "\nStep 3: Creating PersistentVolumeClaim" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "02-storage\redis-pvc.yaml")

Write-Host "\nStep 4: Deploying Redis" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "03-data")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "redis" -Timeout 120

Write-Host "\nStep 5: Deploying Keycloak" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "04-iam")
Write-Host "Note: Keycloak takes ~90 seconds to start. Waiting..." -ForegroundColor Yellow
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "keycloak" -Timeout 180

Write-Host "\nStep 6: Deploying Authorization Service" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "05-authz")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "authz-service" -Timeout 120

Write-Host "\nStep 7: Deploying Backend Services" -ForegroundColor Cyan
kubectl apply -f (Join-Path $K8sDir "06-services")
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "customer-service" -Timeout 120
Wait-ForDeployment -Namespace "api-gateway-poc" -Deployment "product-service" -Timeout 120

Write-Host "\nStep 8: Deploying Gateway API Resources" -ForegroundColor Cyan
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

$endpointsReady = Wait-ForServiceEndpoint -Namespace "api-gateway-poc" -Service "keycloak" -Timeout 120
if (-not $endpointsReady) { Write-Host "Warning: Keycloak endpoints not ready; attempting to apply SecurityPolicies anyway (may cause JWKS fetch warnings)." -ForegroundColor Yellow }

Write-Host "Applying Security Policies..." -ForegroundColor Yellow
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\07-securitypolicy-jwt.yaml")
kubectl apply -f (Join-Path $K8sDir "08-gateway-api\09-securitypolicy-extauth-noJWT-routes.yaml")

Write-Host "\nDeployment Complete!" -ForegroundColor Green
Write-Host "Backend Services:" -ForegroundColor Cyan
kubectl get pods -n api-gateway-poc | Select-String -Pattern "(redis|keycloak|authz|customer|product)"

Write-Host "\nGateway API Resources:" -ForegroundColor Cyan
Write-Host "Gateway:" -ForegroundColor Yellow
kubectl get gateway -n api-gateway-poc

Write-Host "\nHTTPRoutes:" -ForegroundColor Yellow
kubectl get httproute -n api-gateway-poc

Write-Host "\nSecurityPolicies:" -ForegroundColor Yellow
kubectl get securitypolicy -n api-gateway-poc

Write-Host "\nGateway Service (LoadBalancer):" -ForegroundColor Cyan
kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

Write-Host "\nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Wait for LoadBalancer IP to be assigned (may take a minute)" -ForegroundColor White
Write-Host "2. Run: .\verify-deployment.ps1 to check all components" -ForegroundColor White
Write-Host "3. Run: .\test-endpoints.ps1 to test service endpoints" -ForegroundColor White
