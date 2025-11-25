#!/bin/bash
# Cleanup EnvoyK8SPOC Kubernetes resources (Phase 3 only)
# Removes Phase 3 deployed resources from the cluster

set -e

echo "================================"
echo "Cleaning up EnvoyK8SPOC (Gateway API)"
echo "================================"

NAMESPACE="api-gateway-poc"

read -p "This will delete all resources in namespace $NAMESPACE. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo "Step 1: Deleting SecurityPolicies, HTTPRoutes, and Gateway..."
kubectl delete securitypolicy --all -n $NAMESPACE --ignore-not-found=true || true
kubectl delete httproute --all -n $NAMESPACE --ignore-not-found=true || true
kubectl delete gateway --all -n $NAMESPACE --ignore-not-found=true || true
kubectl delete gatewayclass envoy-gateway --ignore-not-found=true || true

echo "Waiting for Envoy proxy pods to terminate..."
sleep 5

echo "Step 2: Deleting namespace and all backend services..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true || true

# Wait for namespace deletion (timeout after 60 seconds)
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if ! kubectl get namespace $NAMESPACE &>/dev/null; then
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done

echo

echo "Cleanup complete. Envoy Gateway operator (envoy-gateway-system) is left intact for reuse."
