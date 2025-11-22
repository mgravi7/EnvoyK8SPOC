# Build all Docker images for EnvoyK8SPOC
# Images will be available to Docker Desktop Kubernetes automatically

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Building Docker Images" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..") | Select-Object -ExpandProperty Path

Set-Location $RepoRoot

Write-Host ""
Write-Host "Building customer-service..." -ForegroundColor Yellow
docker build -t customer-service:latest `
  -f services/customer-service/Dockerfile `
  services

Write-Host ""
Write-Host "Building product-service..." -ForegroundColor Yellow
docker build -t product-service:latest `
  -f services/product-service/Dockerfile `
  services

Write-Host ""
Write-Host "Building authz-service..." -ForegroundColor Yellow
docker build -t authz-service:latest `
  -f services/authz-service/Dockerfile `
  services

Write-Host ""
Write-Host "Building keycloak..." -ForegroundColor Yellow
docker build -t keycloak:latest `
  -f services/keycloak/Dockerfile `
  services/keycloak

Write-Host ""
Write-Host "Building envoy gateway..." -ForegroundColor Yellow
docker build -t envoy:latest `
  -f services/gateway/Dockerfile `
  services/gateway

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Listing built images:"
docker images | Select-String -Pattern "customer-service|product-service|authz-service|keycloak|envoy" | Select-String -Pattern "latest"

Write-Host ""
Write-Host "Images are ready for Kubernetes deployment"
Write-Host "Run: .\deploy-k8s-phase2.ps1 to deploy to Kubernetes"
