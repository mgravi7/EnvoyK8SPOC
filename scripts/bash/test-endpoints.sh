#!/bin/bash
# Test EnvoyK8SPOC service endpoints (Phase 3 only)
# Verifies services are responding correctly

set -e

echo "================================"
echo "Testing Service Endpoints"
echo "================================"

# Assume Phase 3 deployment
DEPLOYMENT_PHASE="Phase 3 (Gateway API)"
GATEWAY_PORT=8080
ENVOY_ADMIN_AVAILABLE=false

echo "Detected: $DEPLOYMENT_PHASE"

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
# Gateway service is in envoy-gateway-system namespace
kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=api-gateway || true

echo ""
echo "================================"
echo "Testing Health Endpoints"
echo "================================"

# Envoy admin not available in Phase 3
echo ""
echo "Envoy Admin endpoint not available in Phase 3 (managed by Envoy Gateway)"

# Test Keycloak health (management port may vary)
test_endpoint "http://localhost:9000/health/ready" "Keycloak Health (Management Port)"

echo ""
echo "================================"
echo "Testing Service Endpoints (via Gateway)"
echo "================================"

echo ""
echo "Note: Customer endpoint requires JWT authentication"
echo "      Product endpoint allows anonymous access"
echo "These tests check if the Gateway is routing correctly"

test_endpoint "http://localhost:$GATEWAY_PORT/customers" "Customer Service (via Gateway - should be 401)" "401"
test_endpoint "http://localhost:$GATEWAY_PORT/products" "Product Service (via Gateway - anonymous access)" "200"

echo ""
echo "================================"
echo "Testing Keycloak Token Endpoint"
echo "================================"

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
    "http://localhost:$GATEWAY_PORT/customers")
  
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
echo "Deployment Phase: $DEPLOYMENT_PHASE"
echo ""
echo "For manual testing:"
echo "1. Access Keycloak admin: http://localhost:8180 (admin/admin)"
echo "2. Get token: See scripts/bash/test-endpoints.sh for example"
echo "3. Test APIs: curl -H \"Authorization: Bearer \$TOKEN\" http://localhost:$GATEWAY_PORT/customers"
echo ""
echo "To run integration tests:"
echo "1. Update tests/integration/conftest.py GATEWAY_BASE_URL to http://localhost:$GATEWAY_PORT"
echo "2. Run: pytest tests/integration/"
