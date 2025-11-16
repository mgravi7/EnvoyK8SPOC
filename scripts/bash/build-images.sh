#!/bin/bash
# Build all Docker images for EnvoyK8SPOC
# Images will be available to Docker Desktop Kubernetes automatically

set -e

echo "================================"
echo "Building Docker Images"
echo "================================"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

cd "$REPO_ROOT"

echo ""
echo "Building customer-service..."
docker build -t customer-service:latest \
  -f services/customer-service/Dockerfile \
  services

echo ""
echo "Building product-service..."
docker build -t product-service:latest \
  -f services/product-service/Dockerfile \
  services

echo ""
echo "Building authz-service..."
docker build -t authz-service:latest \
  -f services/authz-service/Dockerfile \
  services

echo ""
echo "Building keycloak..."
docker build -t keycloak:latest \
  -f services/keycloak/Dockerfile \
  services/keycloak

echo ""
echo "Building envoy gateway..."
docker build -t envoy:latest \
  -f services/gateway/Dockerfile \
  services/gateway

echo ""
echo "================================"
echo "Build Complete!"
echo "================================"
echo ""
echo "Listing built images:"
docker images | grep -E "customer-service|product-service|authz-service|keycloak|envoy" | grep latest

echo ""
echo "Images are ready for Kubernetes deployment"
echo "Run: ./deploy-k8s-phase2.sh to deploy to Kubernetes"
