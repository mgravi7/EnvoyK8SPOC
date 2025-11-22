#!/bin/bash
# Clean up all EnvoyK8SPOC resources from Kubernetes
# Handles both Phase 2 and Phase 3 deployments

set -e

NAMESPACE="api-gateway-poc"

echo "================================"
echo "Cleaning up EnvoyK8SPOC"
echo "================================"

echo ""
echo "WARNING: This will delete all resources in namespace: $NAMESPACE"
echo "This includes:"
echo "  - Phase 2: Envoy Deployment, ConfigMap, Service"
echo "  - Phase 3: Gateway, HTTPRoutes, SecurityPolicies, GatewayClass"
echo "  - All backend services (Redis, Keycloak, authz-service, etc.)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cleanup cancelled."
    exit 1
fi

echo ""
echo "Step 1: Deleting Phase 3 Gateway API resources (if present)..."
kubectl delete securitypolicy --all -n $NAMESPACE --ignore-not-found=true
kubectl delete httproute --all -n $NAMESPACE --ignore-not-found=true
kubectl delete gateway --all -n $NAMESPACE --ignore-not-found=true
kubectl delete gatewayclass envoy-gateway --ignore-not-found=true

echo ""
echo "Step 2: Deleting namespace and all resources..."
kubectl delete namespace $NAMESPACE

echo ""
echo "Waiting for namespace to be fully deleted..."
kubectl wait --for=delete namespace/$NAMESPACE --timeout=60s || true

echo ""
echo "================================"
echo "Cleanup Complete"
echo "================================"
echo ""
echo "All resources have been removed."
echo ""
echo "To redeploy Phase 2:"
echo "  ./deploy-k8s-phase2.sh"
echo ""
echo "To redeploy Phase 3:"
echo "  ./deploy-k8s-phase3.sh"
echo ""
echo "To rebuild images:"
echo "  ./build-images.sh"
echo ""
echo "NOTE: Envoy Gateway operator (envoy-gateway-system) was NOT deleted."
echo "      It can be reused for future Phase 3 deployments."
echo "      To uninstall Envoy Gateway:"
echo "      kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml"
