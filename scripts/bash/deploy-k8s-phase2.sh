#!/bin/bash
# Deploy EnvoyK8SPOC Phase 2 to Kubernetes
# Applies all manifests in correct order with wait logic

set -e

echo "================================"
echo "Deploying EnvoyK8SPOC Phase 2"
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

# Function to wait for pod
wait_for_pod() {
  local namespace=$1
  local label=$2
  local timeout=${3:-300}
  
  echo "Waiting for pod with label $label to be ready..."
  kubectl wait --for=condition=ready --timeout=${timeout}s \
    pod -l $label -n $namespace
}

echo ""
echo "Step 1: Creating namespace..."
kubectl apply -f "$K8S_DIR/00-namespace/namespace.yaml"

echo ""
echo "Step 2: Creating ConfigMaps and Secrets..."
kubectl apply -f "$K8S_DIR/01-config/"

echo ""
echo "Step 3: Creating PersistentVolumeClaim for Redis..."
kubectl apply -f "$K8S_DIR/02-storage/redis-pvc.yaml"

echo ""
echo "Step 4: Deploying Redis..."
kubectl apply -f "$K8S_DIR/03-data/"
wait_for_deployment api-gateway-poc redis 120

echo ""
echo "Step 5: Deploying Keycloak..."
kubectl apply -f "$K8S_DIR/04-iam/"
echo "Note: Keycloak takes ~90 seconds to start. Waiting..."
wait_for_deployment api-gateway-poc keycloak 180

echo ""
echo "Step 6: Deploying Authorization Service..."
kubectl apply -f "$K8S_DIR/05-authz/"
wait_for_deployment api-gateway-poc authz-service 120

echo ""
echo "Step 7: Deploying Backend Services..."
kubectl apply -f "$K8S_DIR/06-services/"
wait_for_deployment api-gateway-poc customer-service 120
wait_for_deployment api-gateway-poc product-service 120

echo ""
echo "Step 8: Deploying Envoy Gateway..."
kubectl apply -f "$K8S_DIR/07-envoy-gateway/"
wait_for_deployment api-gateway-poc envoy 120

echo ""
echo "================================"
echo "Deployment Complete!"
echo "================================"
echo ""
echo "Checking pod status:"
kubectl get pods -n api-gateway-poc

echo ""
echo "Checking services:"
kubectl get svc -n api-gateway-poc

echo ""
echo "================================"
echo "Next Steps:"
echo "================================"
echo "1. Wait for LoadBalancer IPs to be assigned (may take a minute)"
echo "2. Run: ./verify-deployment.sh to check all components"
echo "3. Run: ./test-endpoints.sh to test service endpoints"
echo "4. Access services:"
echo "   - Keycloak: http://localhost:8180"
echo "   - Envoy Gateway: http://localhost:8080"
echo "   - Envoy Admin: http://localhost:9901"
