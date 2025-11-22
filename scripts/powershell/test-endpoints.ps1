# Test EnvoyK8SPOC service endpoints
# Verifies services are responding correctly

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Service Endpoints" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

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
kubectl get svc -n api-gateway-poc envoy keycloak

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Health Endpoints" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Test Envoy admin
Test-Endpoint -Url "http://localhost:9901/ready" -Description "Envoy Admin - Ready"

# Test Keycloak health (management port 9000)
Test-Endpoint -Url "http://localhost:9000/health/ready" -Description "Keycloak Health (Management Port)"

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Testing Service Endpoints (via Envoy)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Note: Customer and Product endpoints require JWT authentication" -ForegroundColor Yellow
Write-Host "These tests check if Envoy is routing (expect 401 Unauthorized)" -ForegroundColor Yellow

Test-Endpoint -Url "http://localhost:8080/customers" -Description "Customer Service (via Envoy - should be 401)" -ExpectedStatus 401
Test-Endpoint -Url "http://localhost:8080/products" -Description "Product Service (via Envoy)" -ExpectedStatus 200

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
            $authResponse = Invoke-WebRequest -Uri "http://localhost:8080/customers" `
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
Write-Host "For manual testing:"
Write-Host "1. Access Keycloak admin: http://localhost:8180 (admin/admin)"
Write-Host "2. Get token: See scripts/powershell/test-endpoints.ps1 for example"
Write-Host "3. Test APIs: curl -H 'Authorization: Bearer `$TOKEN' http://localhost:8080/customers"
Write-Host ""
Write-Host "To run integration tests:"
Write-Host "1. Update tests/integration/conftest.py GATEWAY_BASE_URL to http://localhost:8080"
Write-Host "2. Run: pytest tests/integration/"
