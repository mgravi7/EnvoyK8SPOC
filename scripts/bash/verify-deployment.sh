#!/bin/bash
# Verify EnvoyK8SPOC deployment (Phase 2 or Phase 3)
# Checks pod status, service endpoints, and component health

set -e

NAMESPACE="api-gateway-poc"

echo "================================"
echo "Verifying Deployment"
echo "================================"

# Detect which phase is deployed
PHASE2_ENVOY=$(kubectl get deployment envoy -n $NAMESPACE --ignore-not-found=true 2>/dev/null)
PHASE3_GATEWAY=$(kubectl get gateway -n $NAMESPACE --ignore-not-found=true 2>/dev/null)

if [ -n "$PHASE3_GATEWAY" ]; then
  DEPLOYMENT_PHASE="Phase 3 (Gateway API)"
elif [ -n "$PHASE2_ENVOY" ]; then
  DEPLOYMENT_PHASE="Phase 2 (Direct Envoy)"
else
  DEPLOYMENT_PHASE="Unknown (no gateway detected)"
fi

echo "Detected: $DEPLOYMENT_PHASE"

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

if [ -n "$PHASE3_GATEWAY" ]; then
  echo ""
  echo "9. Checking Gateway API resources (Phase 3)..."
  
  echo ""
  echo "Gateway:"
  kubectl get gateway -n $NAMESPACE
  echo ""
  kubectl describe gateway -n $NAMESPACE | grep -A 10 "Status:"
  
  echo ""
  echo "HTTPRoutes:"
  kubectl get httproute -n $NAMESPACE
  
  echo ""
  echo "SecurityPolicies:"
  kubectl get securitypolicy -n $NAMESPACE
  
  echo ""
  echo "GatewayClass:"
  kubectl get gatewayclass envoy-gateway 2>/dev/null || echo "GatewayClass not found"
fi

echo ""
echo "10. Checking recent logs for each service..."

echo ""
echo "Redis logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/redis --tail=10 2>/dev/null || echo "No logs available"

echo ""
echo "Keycloak logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/keycloak --tail=10 2>/dev/null || echo "No logs available"

echo ""
echo "AuthZ Service logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/authz-service --tail=10 2>/dev/null || echo "No logs available"

echo ""
echo "Customer Service logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/customer-service --tail=10 2>/dev/null || echo "No logs available"

echo ""
echo "Product Service logs (last 10 lines):"
kubectl logs -n $NAMESPACE deployment/product-service --tail=10 2>/dev/null || echo "No logs available"

if [ -n "$PHASE2_ENVOY" ]; then
  echo ""
  echo "Envoy logs (last 10 lines) - Phase 2:"
  kubectl logs -n $NAMESPACE deployment/envoy --tail=10 2>/dev/null || echo "No logs available"
fi

if [ -n "$PHASE3_GATEWAY" ]; then
  echo ""
  echo "Gateway Envoy Proxy logs (last 10 lines) - Phase 3:"
  kubectl logs -n $NAMESPACE -l gateway.envoyproxy.io/owning-gateway-name=api-gateway --tail=10 2>/dev/null || echo "No logs available"
fi

echo ""
echo "================================"
echo "Verification Summary"
echo "================================"

RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep Running | wc -l)
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)

echo "Deployment Phase: $DEPLOYMENT_PHASE"
echo "Pods running: $RUNNING_PODS / $TOTAL_PODS"

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
  echo "Status: ✓ All pods are running!"
else
  echo "Status: ✗ Some pods are not running. Check logs above."
fi

echo ""
echo "Useful commands:"
echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
echo "  kubectl logs -f deployment/<deployment-name> -n $NAMESPACE"

if [ -n "$PHASE3_GATEWAY" ]; then
  echo "  kubectl describe gateway api-gateway -n $NAMESPACE"
  echo "  kubectl logs -n $NAMESPACE -l gateway.envoyproxy.io/owning-gateway-name=api-gateway"
fi
