# Test EnvoyK8SPOC service endpoints (Phase 3 only)
# Verifies services are responding correctly

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Service Endpoints" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$deploymentPhase = "Phase 3 (Gateway API)"
$gatewayPort = 8080

Write-Host "Detected: $deploymentPhase" -ForegroundColor Yellow

# Function to test endpoint
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Description,
        [int]$ExpectedStatus = 200
    )
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
Write-Host "Waiting for LoadBalancer services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Getting LoadBalancer details..." -ForegroundColor Yellow
# kubectl is an external command; capture output and check exit code instead of shell-style ||
$svcResult = kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Gateway service not found yet" -ForegroundColor Yellow
} else {
    Write-Host $svcResult
}

Write-Host "Testing Health Endpoints" -ForegroundColor Cyan

# Test Keycloak health (management port 9000)
Test-Endpoint -Url "http://localhost:9000/health/ready" -Description "Keycloak Health (Management Port)"

Write-Host "Testing Service Endpoints (via Gateway)" -ForegroundColor Cyan
Write-Host "Note: Customer endpoint requires JWT authentication" -ForegroundColor Yellow
Write-Host "      Product endpoint allows anonymous access" -ForegroundColor Yellow

Test-Endpoint -Url "http://localhost:$gatewayPort/customers" -Description "Customer Service (via Gateway - should be 401)" -ExpectedStatus 401
Test-Endpoint -Url "http://localhost:$gatewayPort/products" -Description "Product Service (via Gateway - anonymous access)" -ExpectedStatus 200

Write-Host "Testing Keycloak Token Endpoint" -ForegroundColor Cyan
# Get token from Keycloak
Write-Host "Attempting to get JWT token from Keycloak..." -ForegroundColor Yellow

$tokenBody = @{
    client_id = "test-client"
    username = "testuser"
    password = "testpass"
    grant_type = "password"
}

try {
    $tokenResponse = Invoke-RestMethod -Uri "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
    if ($tokenResponse.access_token) {
        Write-Host "Result: PASS - Successfully obtained token" -ForegroundColor Green
        $token = $tokenResponse.access_token

        Write-Host "Testing authenticated request to customer service..." -ForegroundColor Yellow
        try {
            $authResponse = Invoke-WebRequest -Uri "http://localhost:$gatewayPort/customers" -Method Get -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing -ErrorAction Stop
            if ($authResponse.StatusCode -eq 200) {
                Write-Host "Result: PASS - Authenticated request successful (HTTP $($authResponse.StatusCode))" -ForegroundColor Green
            } else {
                Write-Host "Result: FAIL - Expected HTTP 200, got HTTP $($authResponse.StatusCode)" -ForegroundColor Red
            }
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "Result: FAIL - Expected HTTP 200, got HTTP $statusCode" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Result: FAIL - Could not obtain token" -ForegroundColor Red
}

Write-Host "Endpoint Testing Complete" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Phase: $deploymentPhase" -ForegroundColor White
Write-Host ""
Write-Host "For manual testing:" -ForegroundColor White
Write-Host "1. Access Keycloak admin: http://localhost:8180 (admin/admin)" -ForegroundColor White
Write-Host "2. Get token: See scripts/powershell/test-endpoints.ps1 for example" -ForegroundColor White
Write-Host "3. Test APIs: curl -H 'Authorization: Bearer $TOKEN' http://localhost:$gatewayPort/customers" -ForegroundColor White
Write-Host ""
Write-Host "To run integration tests:" -ForegroundColor White
Write-Host "1. Update tests/integration/conftest.py GATEWAY_BASE_URL to http://localhost:$gatewayPort" -ForegroundColor White
Write-Host "2. Run: pytest tests/integration/" -ForegroundColor White
