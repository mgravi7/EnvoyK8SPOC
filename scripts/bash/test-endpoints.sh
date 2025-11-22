#!/bin/bash
# Test EnvoyK8SPOC service endpoints
# Verifies services are responding correctly

set -e

echo "================================"
echo "Testing Service Endpoints"
echo "================================"

# Function to test endpoint
test_endpoint() {
  local url=$1
  local description=$2
  local expected_status=${3:-200}
  
  echo ""
  echo "Testing: $description"
  echo "URL: $url"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
  
  if [ "$response" = "$expected_status" ]; then
    echo "Result: PASS (HTTP $response)"
  else
    echo "Result: FAIL (Expected HTTP $expected_status, got HTTP $response)"
  fi
}

# Wait for LoadBalancer to be ready
echo ""
echo "Waiting for LoadBalancer services to be ready..."
sleep 5

echo ""
echo "Getting LoadBalancer IPs..."
kubectl get svc -n api-gateway-poc envoy keycloak

echo ""
echo "================================"
echo "Testing Health Endpoints"
echo "================================"

# Test Envoy admin
test_endpoint "http://localhost:9901/ready" "Envoy Admin - Ready"

# Test Keycloak health
test_endpoint "http://localhost:9000/health/ready" "Keycloak Health (Management Port)"

echo ""
echo "================================"
echo "Testing Service Endpoints (via Envoy)"
echo "================================"

# Note: These will fail without authentication
# We're just checking if Envoy routes to the services

echo ""
echo "Note: Customer and Product endpoints require JWT authentication"
echo "These tests check if Envoy is routing (expect 401 Unauthorized)"

test_endpoint "http://localhost:8080/customers" "Customer Service (via Envoy - should be 401)" "401"
test_endpoint "http://localhost:8080/products" "Product Service (via Envoy)" "200"

echo ""
echo "================================"
echo "Testing Keycloak Token Endpoint"
echo "================================"

# Get token from Keycloak
echo ""
echo "Attempting to get JWT token from Keycloak..."
TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8180/realms/api-gateway-poc/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" || echo "{}")

if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
  echo "Result: PASS - Successfully obtained token"
  
  TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
  
  echo ""
  echo "Testing authenticated request to customer service..."
  AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    "http://localhost:8080/customers")
  
  if [ "$AUTH_RESPONSE" = "200" ]; then
    echo "Result: PASS - Authenticated request successful (HTTP $AUTH_RESPONSE)"
  else
    echo "Result: FAIL - Expected HTTP 200, got HTTP $AUTH_RESPONSE"
  fi
else
  echo "Result: FAIL - Could not obtain token"
  echo "Response: $TOKEN_RESPONSE"
fi

echo ""
echo "================================"
echo "Endpoint Testing Complete"
echo "================================"
echo ""
echo "For manual testing:"
echo "1. Access Keycloak admin: http://localhost:8180 (admin/admin)"
echo "2. Get token: See scripts/bash/test-endpoints.sh for example"
echo "3. Test APIs: curl -H \"Authorization: Bearer \$TOKEN\" http://localhost:8080/customers"
echo ""
echo "To run integration tests:"
echo "1. Update tests/integration/conftest.py GATEWAY_BASE_URL to http://localhost:8080"
echo "2. Run: pytest tests/integration/"
