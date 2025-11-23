#!/bin/bash
# Cleanup EnvoyK8SPOC Kubernetes resources
# Removes all deployed resources from the cluster

set -e

echo "================================"
echo "Cleaning up EnvoyK8SPOC"
echo "================================"

# Detect which phase is deployed
PHASE2_ENVOY=$(kubectl get deployment envoy -n api-gateway-poc --ignore-not-found=true 2>/dev/null)
PHASE3_GATEWAY=$(kubectl get gateway -n api-gateway-poc --ignore-not-found=true 2>/dev/null)

if [ -n "$PHASE3_GATEWAY" ]; then
    DEPLOYED_PHASE="Phase 3 (Gateway API)"
elif [ -n "$PHASE2_ENVOY" ]; then
    DEPLOYED_PHASE="Phase 2 (Direct Envoy)"
else
    DEPLOYED_PHASE="Unknown or not deployed"
fi

echo ""
echo "Detected deployment: $DEPLOYED_PHASE"
echo ""
echo "WARNING: This will delete all resources"

if [ -n "$PHASE3_GATEWAY" ]; then
    echo "- Phase 3: Gateway API resources from api-gateway-poc"
    echo "- Phase 3: Envoy proxy pods from envoy-gateway-system"
    echo "- All backend services (Redis, Keycloak, authz-service, etc.)"
elif [ -n "$PHASE2_ENVOY" ]; then
    echo "- Phase 2: Envoy Deployment from api-gateway-poc"
    echo "- All backend services (Redis, Keycloak, authz-service, etc.)"
else
    echo "- All resources in namespace: api-gateway-poc"
fi

echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""

if [ -n "$PHASE3_GATEWAY" ]; then
    echo "Step 1: Deleting Phase 3 Gateway API resources..."
    
    # Delete SecurityPolicies first (they reference HTTPRoutes/Gateway)
    echo "- Deleting SecurityPolicies..."
    kubectl delete securitypolicy --all -n api-gateway-poc --ignore-not-found=true
    
    # Delete HTTPRoutes (they reference Gateway)
    echo "- Deleting HTTPRoutes..."
    kubectl delete httproute --all -n api-gateway-poc --ignore-not-found=true
    
    # Delete Gateway (this will trigger Envoy proxy deletion)
    echo "- Deleting Gateway..."
    kubectl delete gateway --all -n api-gateway-poc --ignore-not-found=true
    
    # Delete GatewayClass
    echo "- Deleting GatewayClass..."
    kubectl delete gatewayclass envoy-gateway --ignore-not-found=true
    
    echo ""
    echo "Waiting for Envoy proxy pod to terminate..."
    sleep 5
    
elif [ -n "$PHASE2_ENVOY" ]; then
    echo "Step 1: Deleting Phase 2 Envoy resources..."
    kubectl delete -f ../../kubernetes/07-envoy-gateway --ignore-not-found=true
fi

echo ""
echo "Step 2: Deleting namespace and all backend services..."
kubectl delete namespace api-gateway-poc --ignore-not-found=true

echo ""
echo "Waiting for namespace to be fully deleted..."

# Wait for namespace deletion (timeout after 60 seconds)
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if ! kubectl get namespace api-gateway-poc &>/dev/null; then
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done
echo ""

if [ -n "$PHASE3_GATEWAY" ]; then
    echo ""
    echo "Phase 3 Cleanup:"
    echo "The Envoy Gateway operator is still running in envoy-gateway-system namespace."
    echo "It can be reused for future Phase 3 deployments."
    echo ""
    read -p "Do you want to delete the Envoy Gateway operator? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Deleting Envoy Gateway operator..."
        kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml --ignore-not-found=true
        
        echo ""
        echo "Waiting for envoy-gateway-system namespace to be deleted..."
        sleep 5
        echo "Envoy Gateway operator deleted."
    else
        echo "Envoy Gateway operator kept (recommended for reuse)."
    fi
fi

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
if [ -n "$PHASE3_GATEWAY" ] && [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "  ./deploy-k8s-phase3.sh (Envoy Gateway already installed)"
else
    echo "  1. Install Envoy Gateway first:"
    echo "     kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml"
    echo "  2. Deploy Phase 3:"
    echo "     ./deploy-k8s-phase3.sh"
fi
echo ""
echo "To rebuild images:"
echo "  ./build-images.sh"
