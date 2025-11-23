#!/bin/bash
# Deploy EnvoyK8SPOC Phase 3 to Kubernetes using Gateway API
# This script deploys backend services + Gateway API resources (NOT Phase 2 Envoy)

set -e

echo "================================"
echo "Deploying EnvoyK8SPOC Phase 3"
echo "================================"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
K8S_DIR="$REPO_ROOT/kubernetes"

cd "$REPO_ROOT"

# Function to wait for deployment
wait_for_deployment() {
  local namespace=$1
  local deployment=$2
  local timeout=${3:-300}
  
  echo "Waiting for deployment/$deployment to be ready..."
  kubectl wait --for=condition=available --timeout=${timeout}s \
    deployment/$deployment -n $namespace
}

# Function to wait for Gateway to be ready
wait_for_gateway() {
  local namespace=$1
  local gateway=$2
  local timeout=${3:-300}
  
  echo "Waiting for gateway/$gateway to be ready..."
  # Gateway readiness check
  timeout_end=$((SECONDS + timeout))
  while [ $SECONDS -lt $timeout_end ]; do
    # NOTE: JSONPath expression uses double quotes inside and single quotes outside to
    # avoid shell interpolation issues in `bash`. Do not change the quoting here unless
    # you understand shell quoting rules.
    status=$(kubectl get gateway $gateway -n $namespace -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Unknown")
    if [ "$status" = "True" ]; then
      echo "Gateway $gateway is ready!"
      return 0
    fi
    # Also check envoy proxy pod readiness in envoy-gateway-system
    proxy_ready=$(kubectl get pods -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=$gateway" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null || echo "")
    if [[ "$proxy_ready" =~ "true" ]]; then
      echo "Envoy proxy pod for $gateway is ready!"
      return 0
    fi
    echo "Gateway status: $status - waiting..."
    sleep 5
  done
  echo "Warning: Gateway did not become ready within ${timeout}s"
  echo "Gateway diagnostics: listing proxy pods and last 50 log lines"
  kubectl get pods -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=$gateway" -o wide || true
  kubectl logs -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=$gateway" --tail=50 2>&1 || true
  return 1
}

# Function to wait for a service to have endpoints
wait_for_service_endpoints() {
  local namespace=$1
  local service=$2
  local timeout=${3:-120}
  echo "Waiting for service endpoint $service in namespace $namespace..."
  timeout_end=$((SECONDS + timeout))
  attempt=0
  while [ $SECONDS -lt $timeout_end ]; do
    attempt=$((attempt+1))
    # Try EndpointSlices first
    ips=$(kubectl get endpointslices -n $namespace -l "kubernetes.io/service-name=$service" -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null || echo "")
    if [ -z "$ips" ]; then
      # Fallback to legacy Endpoints
      ips=$(kubectl get endpoints $service -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    fi
    ips=$(echo "$ips" | xargs) # trim
    echo "Attempt:$attempt, endpoints='$ips'"
    if [[ "$ips" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
      echo "Service $service has endpoints: $ips"
      return 0
    fi
    sleep 5
  done
  echo "Warning: Service $service did not have endpoints within ${timeout}s"
  echo "Diagnostics: endpoints and endpointSlices" 
  kubectl get endpoints $service -n $namespace -o yaml || true
  kubectl get endpointslices -n $namespace -l "kubernetes.io/service-name=$service" -o yaml || true
  kubectl describe pod -l app=keycloak -n $namespace || true
  kubectl get events -n $namespace --sort-by='.lastTimestamp' | tail -n 50 || true
  return 1
}

echo ""
echo "=========================================="
echo "Step 0: Pre-flight Checks"
echo "=========================================="

# Check if Envoy Gateway is installed
echo "Checking if Envoy Gateway is installed..."
if ! kubectl get namespace envoy-gateway-system &>/dev/null; then
  echo ""
  echo "ERROR: Envoy Gateway is not installed!"
  echo ""
  echo "Please install Envoy Gateway first:"
  echo "  kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml"
  echo "  kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available"
  echo ""
  echo "Or refer to: kubernetes/08-gateway-api/00-install-envoy-gateway.yaml"
  exit 1
fi

# Verify Envoy Gateway is running
if ! kubectl wait --timeout=10s -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available &>/dev/null; then
  echo "Warning: Envoy Gateway deployment is not ready. Continuing anyway..."
fi

echo "✓ Envoy Gateway is installed"

# Check if Phase 2 Envoy is running (warn if present)
if kubectl get deployment envoy -n api-gateway-poc &>/dev/null; then
  echo ""
  echo "WARNING: Phase 2 Envoy deployment is still running!"
  echo "Phase 3 and Phase 2 cannot run simultaneously (port conflicts)."
  echo ""
  read -p "Do you want to delete Phase 2 Envoy resources? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting Phase 2 Envoy resources..."
    kubectl delete -f "$K8S_DIR/07-envoy-gateway/" --ignore-not-found=true
    echo "Phase 2 Envoy resources deleted."
  else
    echo "Please manually delete Phase 2 Envoy before proceeding:"
    echo "  kubectl delete -f kubernetes/07-envoy-gateway/"
    exit 1
  fi
fi

echo ""
echo "=========================================="
echo "Step 1: Creating namespace"
echo "=========================================="
kubectl apply -f "$K8S_DIR/00-namespace/namespace.yaml"

echo ""
echo "=========================================="
echo "Step 2: Creating ConfigMaps and Secrets"
echo "=========================================="
kubectl apply -f "$K8S_DIR/01-config/"

echo ""
echo "=========================================="
echo "Step 3: Creating PersistentVolumeClaim"
echo "=========================================="
kubectl apply -f "$K8S_DIR/02-storage/redis-pvc.yaml"

echo ""
echo "=========================================="
echo "Step 4: Deploying Redis"
echo "=========================================="
kubectl apply -f "$K8S_DIR/03-data/"
wait_for_deployment api-gateway-poc redis 120

echo ""
echo "=========================================="
echo "Step 5: Deploying Keycloak"
echo "=========================================="
kubectl apply -f "$K8S_DIR/04-iam/"
echo "Note: Keycloak takes ~90 seconds to start. Waiting..."
wait_for_deployment api-gateway-poc keycloak 180

echo ""
echo "=========================================="
echo "Step 6: Deploying Authorization Service"
echo "=========================================="
kubectl apply -f "$K8S_DIR/05-authz/"
wait_for_deployment api-gateway-poc authz-service 120

echo ""
echo "=========================================="
echo "Step 7: Deploying Backend Services"
echo "=========================================="
kubectl apply -f "$K8S_DIR/06-services/"
wait_for_deployment api-gateway-poc customer-service 120
wait_for_deployment api-gateway-poc product-service 120

echo ""
echo "=========================================="
echo "Step 8: Deploying Gateway API Resources"
echo "=========================================="
echo "Creating GatewayClass..."
kubectl apply -f "$K8S_DIR/08-gateway-api/01-gatewayclass.yaml"

echo "Creating Gateway..."
kubectl apply -f "$K8S_DIR/08-gateway-api/02-gateway.yaml"
wait_for_gateway api-gateway-poc api-gateway 180

echo "Creating HTTPRoutes..."
kubectl apply -f "$K8S_DIR/08-gateway-api/03-httproute-customer.yaml"
kubectl apply -f "$K8S_DIR/08-gateway-api/04-httproute-product.yaml"
kubectl apply -f "$K8S_DIR/08-gateway-api/05-httproute-auth-me.yaml"
kubectl apply -f "$K8S_DIR/08-gateway-api/06-httproute-keycloak.yaml"

# Ensure Keycloak service endpoints exist before applying SecurityPolicies (prevents JWKS race)
if ! wait_for_service_endpoints api-gateway-poc keycloak 120; then
  echo "Warning: Keycloak endpoints not ready; attempting to apply SecurityPolicies anyway (may cause JWKS fetch warnings)."
fi

echo "Applying Security Policies..."
kubectl apply -f "$K8S_DIR/08-gateway-api/07-securitypolicy-jwt.yaml"
# Apply extAuth policy for public routes so backends receive x-user-roles (no JWT required)
kubectl apply -f "$K8S_DIR/08-gateway-api/09-securitypolicy-extauth-noJWT-routes.yaml"
# The old external-authorization file has been merged into the combined SecurityPolicy. Do not apply 08-securitypolicy-extauth.yaml
# kubectl apply -f "$K8S_DIR/08-gateway-api/08-securitypolicy-extauth.yaml"

echo ""
echo "================================"
echo "Deployment Complete!"
echo "================================"
echo ""
echo "Backend Services:"
kubectl get pods -n api-gateway-poc | grep -E "(redis|keycloak|authz|customer|product)"

echo ""
echo "Gateway API Resources:"
echo "Gateway:"
kubectl get gateway -n api-gateway-poc
echo ""
echo "HTTPRoutes:"
kubectl get httproute -n api-gateway-poc
echo ""
echo "SecurityPolicies:"
kubectl get securitypolicy -n api-gateway-poc

echo ""
echo "Gateway Service (LoadBalancer):"
kubectl get svc -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway

echo ""
echo "================================"
echo "Next Steps:"
echo "================================"
echo "1. Wait for LoadBalancer IP to be assigned (may take a minute)"
echo "2. Run: ./verify-deployment.sh to check all components"
echo "3. Run: ./test-endpoints.sh to test service endpoints"
echo "4. Access services:"
echo "   - API Gateway: http://localhost:8080"
echo "   - Keycloak: http://localhost:8080/auth"
echo ""
echo "5. Check Gateway status:"
echo "   kubectl describe gateway api-gateway -n api-gateway-poc"
echo ""
echo "6. View Envoy proxy logs:"
echo "   kubectl logs -n api-gateway-poc -l gateway.envoyproxy.io/owning-gateway-name=api-gateway"
