#!/bin/bash
# Clean up all EnvoyK8SPOC Phase 2 resources from Kubernetes

set -e

NAMESPACE="api-gateway-poc"

echo "================================"
echo "Cleaning up EnvoyK8SPOC Phase 2"
echo "================================"

echo ""
echo "WARNING: This will delete all resources in namespace: $NAMESPACE"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cleanup cancelled."
    exit 1
fi

echo ""
echo "Deleting namespace and all resources..."
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
echo "To redeploy:"
echo "  ./deploy-k8s-phase2.sh"
echo ""
echo "To rebuild images:"
echo "  ./build-images.sh"
