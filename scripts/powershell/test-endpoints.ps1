# Test EnvoyK8SPOC service endpoints
# Verifies services are responding correctly

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Service Endpoints" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Detect which phase is deployed
$phase2Envoy = kubectl get deployment envoy -n api-gateway-poc --ignore-not-found=true 2>$null
$phase3Gateway = kubectl get gateway -n api-gateway-poc --ignore-not-found=true 2>$null

if ($phase3Gateway) {
    $deploymentPhase = "Phase 3 (Gateway API)"
    $gatewayPort = 8080
    $envoyAdminAvailable = $false
} elseif ($phase2Envoy) {
    $deploymentPhase = "Phase 2 (Direct Envoy)"
    $gatewayPort = 8080
    $envoyAdminAvailable = $true
} else {
    $deploymentPhase = "Unknown (no gateway detected)"
    Write-Host "ERROR: No gateway deployment detected!" -ForegroundColor Red
    exit 1
}

Write-Host "Detected: $deploymentPhase" -ForegroundColor Yellow

# Function to test endpoint
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Description,
        [int]$ExpectedStatus = 200
    )
    
    Write-Host ""
    Write-Host "Testing: $Description" -ForegroundColor Yellow
    Write-Host "URL: $Url"
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -ErrorAction SilentlyContinue
        $statusCode = $response.StatusCode
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-not $statusCode) { $statusCode = 0 }
    }
    
    if ($statusCode -eq $ExpectedStatus) {
        Write-Host "Result: PASS (HTTP $statusCode)" -ForegroundColor Green
    } else {
        Write-Host "Result: FAIL (Expected HTTP $ExpectedStatus, got HTTP $statusCode)" -ForegroundColor Red
    }
}

# Wait for LoadBalancer to be ready
Write-Host ""
Write-Host "Waiting for LoadBalancer services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Getting LoadBalancer IPs..."
if ($phase2Envoy) {
    kubectl get svc -n api-gateway-poc envoy keycloak
} else {
    # Phase 3 - Gateway creates its own service in envoy-gateway-system
    Write-Host "Keycloak service:"
    kubectl get svc keycloak -n api-gateway-poc
    Write-Host ""
    Write-Host "Gateway service (in envoy-gateway-system):"
    kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway 2>$null
    if ($LASTEXITCODE -ne 0) { 
        Write-Host "Note: Gateway service details not available via label selector" -ForegroundColor Yellow
        Write-Host "Gateway is accessible at http://localhost:$gatewayPort" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Health Endpoints" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Test Envoy admin (Phase 2 only)
if ($envoyAdminAvailable) {
    Test-Endpoint -Url "http://localhost:9901/ready" -Description "Envoy Admin - Ready (Phase 2)"
} else {
    Write-Host ""
    Write-Host "Envoy Admin endpoint not available in Phase 3 (managed by Envoy Gateway)" -ForegroundColor Yellow
}

# Test Keycloak health (management port 9000)
Test-Endpoint -Url "http://localhost:9000/health/ready" -Description "Keycloak Health (Management Port)"

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Service Endpoints (via Gateway)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Note: Customer endpoint requires JWT authentication" -ForegroundColor Yellow
Write-Host "      Product endpoint allows anonymous access" -ForegroundColor Yellow
Write-Host "These tests check if the Gateway is routing correctly" -ForegroundColor Yellow

Test-Endpoint -Url "http://localhost:$gatewayPort/customers" -Description "Customer Service (via Gateway - should be 401)" -ExpectedStatus 401
Test-Endpoint -Url "http://localhost:$gatewayPort/products" -Description "Product Service (via Gateway - anonymous access)" -ExpectedStatus 200

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Keycloak Token Endpoint" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get token from Keycloak
Write-Host ""
Write-Host "Attempting to get JWT token from Keycloak..." -ForegroundColor Yellow

$tokenBody = @{
    client_id = "test-client"
    username = "testuser"
    password = "testpass"
    grant_type = "password"
}

try {
    $tokenResponse = Invoke-RestMethod -Uri "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" `
        -Method Post `
        -Body $tokenBody `
        -ContentType "application/x-www-form-urlencoded" `
        -ErrorAction Stop
    
    if ($tokenResponse.access_token) {
        Write-Host "Result: PASS - Successfully obtained token" -ForegroundColor Green
        
        $token = $tokenResponse.access_token
        
        Write-Host ""
        Write-Host "Testing authenticated request to customer service..." -ForegroundColor Yellow
        
        $headers = @{
            Authorization = "Bearer $token"
        }
        
        try {
            $authResponse = Invoke-WebRequest -Uri "http://localhost:$gatewayPort/customers" `
                -Method Get `
                -Headers $headers `
                -UseBasicParsing `
                -ErrorAction Stop
            
            if ($authResponse.StatusCode -eq 200) {
                Write-Host "Result: PASS - Authenticated request successful (HTTP $($authResponse.StatusCode))" -ForegroundColor Green
            } else {
                Write-Host "Result: FAIL - Expected HTTP 200, got HTTP $($authResponse.StatusCode)" -ForegroundColor Red
            }
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "Result: FAIL - Expected HTTP 200, got HTTP $statusCode" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "Result: FAIL - Could not obtain token" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Endpoint Testing Complete" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Phase: $deploymentPhase" -ForegroundColor White
Write-Host ""
Write-Host "For manual testing:"
Write-Host "1. Access Keycloak admin: http://localhost:8180 (admin/admin)"
Write-Host "2. Get token: See scripts/powershell/test-endpoints.ps1 for example"
Write-Host "3. Test APIs: curl -H 'Authorization: Bearer `$TOKEN' http://localhost:$gatewayPort/customers"
Write-Host ""
Write-Host "To run integration tests:"
Write-Host "1. Update tests/integration/conftest.py GATEWAY_BASE_URL to http://localhost:$gatewayPort"
Write-Host "2. Run: pytest tests/integration/"
