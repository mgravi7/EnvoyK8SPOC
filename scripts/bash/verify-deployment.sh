#!/bin/bash
# Verify EnvoyK8SPOC Phase 2 deployment
# Checks pod status, service endpoints, and component health

set -e

NAMESPACE="api-gateway-poc"

echo "================================"
echo "Verifying Deployment"
echo "================================"

echo ""
echo "1. Checking namespace..."
kubectl get namespace $NAMESPACE

echo ""
echo "2. Checking all pods..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "3. Checking pod status details..."
kubectl get pods -n $NAMESPACE --no-headers | while read pod rest; do
  status=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
  if [ "$status" != "Running" ]; then
    echo "WARNING: Pod $pod is in $status state"
    echo "Recent events:"
    kubectl describe pod $pod -n $NAMESPACE | tail -20
  fi
done

echo ""
echo "4. Checking services..."
kubectl get svc -n $NAMESPACE

echo ""
echo "5. Checking endpoints..."
kubectl get endpoints -n $NAMESPACE

echo ""
echo "6. Checking ConfigMaps..."
kubectl get configmap -n $NAMESPACE

echo ""
echo "7. Checking Secrets..."
kubectl get secret -n $NAMESPACE

echo ""
echo "8. Checking PVC..."
kubectl get pvc -n $NAMESPACE

echo ""
echo "9. Checking recent logs for each service..."

echo ""
echo "Redis logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/redis --tail=10 || echo "No logs available"

echo ""
echo "Keycloak logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/keycloak --tail=10 || echo "No logs available"

echo ""
echo "AuthZ Service logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/authz-service --tail=10 || echo "No logs available"

echo ""
echo "Customer Service logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/customer-service --tail=10 || echo "No logs available"

echo ""
echo "Product Service logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/product-service --tail=10 || echo "No logs available"

echo ""
echo "Envoy logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/envoy --tail=10 || echo "No logs available"

echo ""
echo "================================"
echo "Verification Summary"
echo "================================"

RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | grep Running | wc -l)
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)

echo "Pods running: $RUNNING_PODS / $TOTAL_PODS"

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
  echo "Status: All pods are running!"
else
  echo "Status: Some pods are not running. Check logs above."
fi

echo ""
echo "To check detailed pod status:"
echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
echo ""
echo "To view full logs:"
echo "  kubectl logs -f deployment/<deployment-name> -n $NAMESPACE"
