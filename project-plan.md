# EnvoyK8SPOC - Project Plan

## Project Overview

**Name:** EnvoyK8SPOC (Envoy Gateway + Kubernetes Proof of Concept)  
**Purpose:** Learning and demonstrating migration from Docker Compose to Kubernetes-native architecture with Envoy Gateway  
**Dev Environment:** Windows 11/MacOS (development), Linux (deployment)  
**Container Runtime:** Docker Desktop with Kubernetes  
**Type:** Proof of Concept & Learning Project

---

## Current State Assessment

- **Phase 1 COMPLETE - Working in Docker Compose.** All services run together via `docker-compose.yml` for local development and quick iteration.
- **Phase 2 (archived) - Direct Envoy.** Phase 2 manifests (direct Envoy Deployment) have been archived in `docs/archive/` and removed from the main deployment flow to reduce complexity.
- **Phase 3 STANDARD - Gateway API (Envoy Gateway).** Kubernetes Gateway API resources, SecurityPolicies, and deployment scripts are present under `kubernetes/08-gateway-api/` and `scripts/*/deploy-k8s.*`. Helm-based Envoy Gateway operator installation (v1.6.0) is the recommended approach for Docker Desktop local clusters.
- **Services:** `customer-service`, `product-service`, `authz-service`, `keycloak`, and `redis` are implemented as FastAPI/containers and have Kubernetes manifests in `kubernetes/06-services/`, `kubernetes/05-authz/`, `kubernetes/04-iam/`, and `kubernetes/03-data/` respectively.
- **Authentication/Authorization:** JWT authentication (Keycloak) and external authorization (authz-service + Redis caching) are implemented and integrated with the gateway via SecurityPolicies.
- **Tests:** Unit and integration tests live in `tests/` (unit + integration). The test suite is substantial for a POC (100+ tests). Run `pytest -q` in the `tests/` directory to get the current totals and to validate the workspace against a deployed gateway.
- **Shared Libraries:** `shared/auth.py` and `shared/common.py` provide cross-service utilities used across services.

**Branch:** `feature/cleanup` (current workspace branch)
**Repository:** https://github.com/mgravi7/EnvoyK8SPOC

---

## Phase 3 Implementation Status

### Completed Tasks ✅

1. **Gateway API Resources**
   - Created GatewayClass, Gateway, HTTPRoute, and SecurityPolicy manifests
   - Configured JWT authentication via SecurityPolicy
   - Configured external authorization via SecurityPolicy
   - All resources in `kubernetes/08-gateway-api/`

2. **Deployment Scripts**
   - Created unified `deploy-k8s.sh` and `deploy-k8s.ps1` (Phase 3 only)
   - Simplified `verify-deployment`, `cleanup-k8s`, `test-endpoints` scripts
   - All scripts assume Gateway API deployment

3. **Documentation**
   - Updated `docs/kubernetes-deployment.md` for Gateway API focus
   - Updated `scripts/README.md` and `scripts/USAGE.md`
   - Archived Phase 2 materials in `docs/archive/`
   - Updated all port-mappings and troubleshooting docs

4. **Cleanup**
   - Removed Phase 2 references from active documentation
   - Cleaned up empty/duplicate kubernetes directories
   - Archived legacy Phase 2 deployment scripts and docs

### Active Directories

**kubernetes/** structure (current):
- `00-namespace/` - Namespace definition
- `01-config/` - ConfigMaps and Secrets
- `02-storage/` - PersistentVolumeClaims (Redis)
- `03-data/` - Redis deployment
- `04-iam/` - Keycloak deployment
- `05-authz/` - Authorization service
- `05-rate-limiting/` - Reserved for future rate limiting features
- `06-services/` - Backend services (customer, product)
- `08-gateway-api/` - Gateway API resources (current deployment standard)

**scripts/** structure (current):
- `bash/` and `powershell/` contain:
  - `build-images.{sh,ps1}` - Build Docker images
  - `deploy-k8s.{sh,ps1}` - Deploy Gateway API resources
  - `verify-deployment.{sh,ps1}` - Verify deployment
  - `test-endpoints.{sh,ps1}` - Test endpoints
  - `cleanup-k8s.{sh,ps1}` - Clean up resources

---

## Phase 4 Planning (Future Enhancements)

### Proposed Features

1. **Rate Limiting**
   - Implement RateLimitPolicy CRD
   - Configure per-route or global rate limits
   - Manifests will live in `kubernetes/05-rate-limiting/`

2. **Observability**
   - Prometheus metrics collection
   - Grafana dashboards
   - Distributed tracing (Jaeger/Zipkin)
   - Centralized logging

3. **Advanced Gateway API Features**
   - Traffic splitting (canary deployments)
   - Request mirroring
   - Header manipulation
   - Cross-namespace routing with ReferenceGrant

4. **Production Readiness**
   - Resource requests/limits for all deployments
   - HorizontalPodAutoscaler
   - NetworkPolicies for network segmentation
   - TLS/HTTPS configuration
   - Secret rotation mechanisms

5. **Enhanced Security**
   - Pod Security Standards
   - Service mesh integration (optional)
   - External secret manager integration (Vault, ExternalSecrets)

---

## Development Workflow

### Standard Deployment (Phase 3)

```bash
# 1. Install Envoy Gateway (one-time)
helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --version v1.6.0 \
  --create-namespace \
  --namespace envoy-gateway-system

# 2. Build images
cd scripts/bash
./build-images.sh

# 3. Deploy
./deploy-k8s.sh

# 4. Verify
./verify-deployment.sh

# 5. Test
./test-endpoints.sh
cd ../../tests
pytest -v
```

### Update Gateway API Resources

```bash
# Edit resource
vi kubernetes/08-gateway-api/03-httproute-customer.yaml

# Apply change (dynamic, no restart needed)
kubectl apply -f kubernetes/08-gateway-api/03-httproute-customer.yaml

# Verify
kubectl describe httproute customer-route -n api-gateway-poc
```

### Cleanup and Redeploy

```bash
cd scripts/bash
./cleanup-k8s.sh
./deploy-k8s.sh
```

---

## Testing Strategy

### Unit Tests
- Service business logic
- Data access layer
- Utility functions
- Run: `pytest tests/unit/`

### Integration Tests
- End-to-end API flows
- Authentication and authorization
- JWT validation
- RBAC enforcement
- Run: `pytest tests/integration/`

### Manual Testing
- Use `test-endpoints.sh` for quick smoke tests
- Keycloak admin console for user/realm management
- kubectl commands for resource inspection

---

## Documentation Structure

### Active Documentation
- `README.md` - Project overview and quick start
- `project-plan.md` - This file (project plan and status)
- `docs/kubernetes-deployment.md` - Deployment guide
- `docs/troubleshooting.md` - Common issues
- `docs/port-mappings.md` - Port reference
- `docs/docker-k8s-config-guidance.md` - Configuration guidance
- `docs/helm-installation-guide.md` - Envoy Gateway installation
- `scripts/README.md` - Script overview
- `scripts/USAGE.md` - Detailed script usage

### Archived Documentation
- `docs/archive/` - Phase 2 materials and historical migration notes

---

## Known Limitations (POC Scope)

1. **Development Credentials**
   - Default Keycloak admin password (admin/admin)
   - Hardcoded secrets in manifests
   - Not suitable for production

2. **No TLS/HTTPS**
   - All traffic is HTTP
   - Production requires TLS termination at Gateway

3. **Single Replica**
   - All services run single replica
   - No high availability

4. **Local Storage**
   - Redis uses local PVC
   - Not suitable for multi-node clusters

5. **Basic Observability**
   - Simple health checks
   - No metrics or tracing yet

---

## Next Steps

1. ✅ **Complete Phase 3** - Gateway API deployment (DONE)
2. **Validate and Stabilize**
   - Run full test suite
   - Document any issues
   - Update troubleshooting guide
3. **Plan Phase 4**
   - Prioritize rate limiting or observability
   - Design implementation approach
   - Update this plan document

---

## Resources

- **Kubernetes Gateway API:** https://gateway-api.sigs.k8s.io/
- **Envoy Gateway:** https://gateway.envoyproxy.io/
- **Keycloak:** https://www.keycloak.org/
- **FastAPI:** https://fastapi.tiangolo.com/

---

**Last Updated:** Current session (feature/cleanup branch)
**Status:** Phase 3 complete and documented. Ready for Phase 4 planning.
