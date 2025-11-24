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
- **Phase 2 IMPLEMENTED - Kubernetes (Direct Envoy).** Kubernetes manifests and deployment scripts for a direct Envoy deployment are present (`kubernetes/07-envoy-gateway/`, `scripts/*/deploy-k8s-phase2.*`). The Phase 2 deployment workflow (build images, apply manifests, verification scripts) is available and used for local cluster testing.
- **Phase 3 READY - Gateway API (Envoy Gateway).** Gateway API resources, SecurityPolicies, and deployment scripts are included under `kubernetes/08-gateway-api/` and `scripts/*/deploy-k8s-phase3.*`. The repo contains documentation and automation for installing the Envoy Gateway controller and deploying Gateway/HTTPRoute/SecurityPolicy resources. Note: Envoy Gateway installs the data plane pods in the `envoy-gateway-system` namespace and requires the operator to be installed in the cluster before deploying Phase 3 resources.
- **Services:** `customer-service`, `product-service`, `authz-service`, `keycloak`, and `redis` are implemented as FastAPI/containers and have Kubernetes manifests in `kubernetes/06-services/`, `kubernetes/05-authz/`, `kubernetes/04-iam/`, and `kubernetes/03-data/` respectively.
- **Authentication/Authorization:** JWT authentication (Keycloak) and external authorization (authz-service + Redis caching) are implemented and integrated with the gateway in both Phase 2 and Phase 3 approaches.
- **Tests:** Unit and integration tests live in `tests/` (unit + integration). The test suite is substantial for a POC (100+ tests). Run `pytest -q` in the `tests/` directory to get the current totals and to validate the workspace against a deployed gateway.
- **Shared Libraries:** `shared/auth.py` and `shared/common.py` provide cross-service utilities used across services.

**Branch:** `doc/updates` (current workspace branch)
**Repository:** https://github.com/mgravi7/EnvoyK8SPOC

---

## Objectives

1. **Phase 1 (COMPLETE):** Working microservices with Envoy, Keycloak, and RBAC in Docker Compose
2. **Phase 2 (Current):** Migrate to Kubernetes (Docker Desktop) with direct Envoy deployment
3. **Phase 3 (Next):** Convert to Kubernetes Gateway API with Envoy Gateway
4. **Phase 4 (Future):** Advanced Kubernetes-native features (optional)

---

## Architecture Evolution

### Phase 1: Docker Compose [COMPLETE]
```
Docker Network (microservices-network)
|
+-- Keycloak (IAM) :8180
+-- Redis (Cache) - internal only
+-- authz-service - internal only (ext_authz + role lookup)
+-- Envoy Gateway :8080, :9901
|   +-- JWT validation
|   +-- ext_authz filter -> authz-service
|   +-- Routes to services
+-- customer-service :8001
+-- product-service :8002
```

### Phase 2: Kubernetes with Direct Envoy (Target)
```
Namespace: api-gateway-poc
|
+-- Keycloak (Deployment + Service)
+-- Redis (Deployment + Service + PVC)
+-- authz-service (Deployment + Service)
+-- Envoy (Deployment + LoadBalancer/NodePort)
|   +-- ConfigMap with envoy.yaml
+-- customer-service (Deployment + Service)
+-- product-service (Deployment + Service)
```

### Phase 3: Kubernetes Gateway API (Future)
```
Namespace: api-gateway-poc
|
+-- Envoy Gateway Operator (envoy-gateway-system)
+-- GatewayClass + Gateway
+-- HTTPRoutes (customer, product, auth)
+-- SecurityPolicies (JWT, ext_authz)
+-- Services (same as Phase 2)
+-- Deployments (same as Phase 2)
```

---

## Technology Stack

- **Container Runtime:** Docker Desktop
- **Orchestration:** Kubernetes (Docker Desktop built-in)
- **API Gateway:** 
  - Phase 2: Envoy Proxy (direct deployment)
  - Phase 3: Envoy Gateway (Gateway API)
- **Backend Services:** FastAPI (Python 3.12)
- **Authentication:** Keycloak (OpenID Connect / OAuth 2.0)
- **Authorization:** Custom authz-service with ext_authz
- **Caching:** Redis
- **Testing:** pytest (unit + integration)
- **Version Control:** Git + GitHub (HTTPS)

---

## Project Structure

```
EnvoyK8SPOC/
+-- README.md
+-- project-plan.md                       # This file
+-- .gitignore
+-- .copilot-instructions.md
+-- docker-compose.yml                    # [WORKING] Phase 1 reference
|
+-- services/                             # [x] All services working
|   +-- customer-service/
|   |   +-- app/
|   |   |   +-- __init__.py
|   |   |   +-- main.py
|   |   |   +-- customer.py
|   |   |   +-- customer_data_access.py
|   |   +-- Dockerfile                    # [WORKING]
|   |   +-- requirements.txt
|   |   +-- .dockerignore
|   |   +-- start.sh
|   |
|   +-- product-service/
|   |   +-- app/
|   |   |   +-- __init__.py
|   |   |   +-- main.py
|   |   |   +-- product.py
|   |   |   +-- product_data_access.py
|   |   +-- Dockerfile                    # [WORKING]
|   |   +-- requirements.txt
|   |   +-- .dockerignore
|   |   +-- start.sh
|   |
|   +-- authz-service/
|   |   +-- main.py
|   |   +-- authz_data_access.py
|   |   +-- redis_cache.py
|   |   +-- Dockerfile                    # [WORKING]
|   |   +-- requirements.txt
|   |   +-- start.sh
|   |   +-- README.md                     # [x] Comprehensive documentation
|   |
|   +-- keycloak/
|   |   +-- Dockerfile                    # [WORKING]
|   |   +-- realm-export.json             # [x] Pre-configured realm with test users
|   |   +-- README.md                     # [x] Comprehensive documentation
|   |
|   +-- gateway/
|   |   +-- Dockerfile                    # [WORKING] Phase 2
|   |   +-- envoy.yaml                    # [WORKING] Phase 2, replaced in Phase 3
|   |
|   +-- shared/
|       +-- __init__.py
|       +-- auth.py                       # [x] JWT utilities
|       +-- common.py                     # [x] Common utilities
|
+-- tests/                                # [x] 100+ tests passing
|   +-- unit/
|   |   +-- __init__.py
|   |   +-- conftest.py
|   |   +-- requirements.txt
|   |   +-- test_customer_service.py
|   |   +-- test_product_service.py
|   |
|   +-- integration/
|       +-- __init__.py
|       +-- test_api_gateway.py
|       +-- test_external_authz.py
|
+-- kubernetes/                           # [TO CREATE] Phase 2
|   +-- 00-namespace/
|   |   +-- namespace.yaml
|   |
|   +-- 01-config/
|   |   +-- configmap-authz.yaml
|   |   +-- configmap-customer.yaml
|   |   +-- configmap-product.yaml
|   |   +-- secret-keycloak.yaml
|   |   +-- secret-client-credentials.yaml
|   |
|   +-- 02-storage/
|   |   +-- redis-pvc.yaml
|   |
|   +-- 03-data/
|   |   +-- redis-deployment.yaml
|   |   +-- redis-service.yaml
|   |
|   +-- 04-iam/
|   |   +-- keycloak-deployment.yaml
|   |   +-- keycloak-service.yaml
|   |
|   +-- 05-authz/
|   |   +-- authz-deployment.yaml
|   |   +-- authz-service.yaml
|   |
|   +-- 06-services/
|   |   +-- customer-deployment.yaml
|   |   +-- customer-service.yaml
|   |   +-- product-deployment.yaml
|   |   +-- product-service.yaml
|   |
|   +-- 07-envoy-gateway/                # Phase 2 - Direct Envoy
|   |   +-- envoy-configmap.yaml
|   |   +-- envoy-deployment.yaml
|   |   +-- envoy-service.yaml
|   |
|   +-- 08-gateway-api/                  # Phase 3 - Gateway API (Future)
|       +-- gatewayclass.yaml
|       +-- gateway.yaml
|       +-- httproute-customer.yaml
|       +-- httproute-product.yaml
|       +-- httproute-auth.yaml
|       +-- securitypolicy-jwt.yaml
|       +-- securitypolicy-authz.yaml
|
+-- scripts/                              # [TO CREATE] Phase 2
|   +-- README.md
|   |
|   +-- bash/                             # Linux/Mac/WSL
|   |   +-- build-images.sh
|   |   +-- deploy-k8s-phase2.sh
|   |   +-- deploy-k8s-phase3.sh
|   |   +-- cleanup-k8s.sh
|   |   +-- test-endpoints.sh
|   |   +-- verify-deployment.sh
|   |
|   +-- powershell/                       # Windows
|       +-- build-images.ps1
|       +-- deploy-k8s-phase2.ps1
|       +-- deploy-k8s-phase3.ps1
|       +-- cleanup-k8s.ps1
|       +-- test-endpoints.ps1
|       +-- verify-deployment.ps1
|
+-- docs/                                 # Essential docs only
    +-- kubernetes-deployment.md          # Phase 2 deployment guide
    +-- gateway-api-migration.md          # Phase 3 migration guide
    +-- troubleshooting.md                # Common issues and solutions
```

---

## Implementation Phases

### Phase 1: Docker Compose POC [COMPLETE]

**Status:** [x] All services working

**Completed:**
- [x] Customer service with RBAC
- [x] Product service with RBAC
- [x] Authorization service with Redis caching
- [x] Keycloak with pre-configured realm
- [x] Envoy gateway with JWT validation and ext_authz
- [x] Shared libraries (auth.py, common.py)
- [x] Comprehensive service documentation

---

### Phase 2: Kubernetes Migration (Direct Envoy) [CURRENT]

**Goal:** Deploy existing Docker Compose setup to Kubernetes with minimal changes

**Branch:** `feature/k8s-basic`  
**Namespace:** `api-gateway-poc`

#### Tasks:

**2.1 - Kubernetes Manifests**
- [ ] Create namespace: `api-gateway-poc`
- [ ] Create ConfigMaps for service environment variables
- [ ] Create Secrets for Keycloak client credentials
- [ ] Create PersistentVolumeClaim for Redis
- [ ] Write Deployment manifests:
  - [ ] redis (with PVC mount)
  - [ ] keycloak (with health checks)
  - [ ] authz-service (depends on redis, keycloak)
  - [ ] customer-service
  - [ ] product-service
  - [ ] envoy (with ConfigMap for envoy.yaml)
- [ ] Write Service manifests:
  - [ ] redis (ClusterIP - internal only)
  - [ ] keycloak (LoadBalancer or NodePort for external access)
  - [ ] authz-service (ClusterIP - internal only)
  - [ ] customer-service (ClusterIP - internal only)
  - [ ] product-service (ClusterIP - internal only)
  - [ ] envoy (LoadBalancer or NodePort for external access)

**2.2 - Build & Load Images**
- [ ] Build all Docker images locally
- [ ] Tag images appropriately (e.g., `customer-service:latest`)
- [ ] Verify images available in Docker Desktop
- [ ] Set `imagePullPolicy: IfNotPresent` in deployments

**2.3 - Deployment Scripts**
- [ ] Create bash scripts (Linux/Mac/WSL):
  - [ ] `build-images.sh` - Build all Docker images
  - [ ] `deploy-k8s-phase2.sh` - Deploy all resources in order
  - [ ] `cleanup-k8s.sh` - Clean up all resources
  - [ ] `test-endpoints.sh` - Test service endpoints
  - [ ] `verify-deployment.sh` - Check pod/service health
- [ ] Create PowerShell scripts (Windows):
  - [ ] `build-images.ps1`
  - [ ] `deploy-k8s-phase2.ps1`
  - [ ] `cleanup-k8s.ps1`
  - [ ] `test-endpoints.ps1`
  - [ ] `verify-deployment.ps1`

**2.4 - Deploy & Verify**
- [ ] Apply namespace
- [ ] Apply ConfigMaps and Secrets
- [ ] Deploy Redis (wait for ready)
- [ ] Deploy Keycloak (wait for ready)
- [ ] Deploy authz-service (wait for ready)
- [ ] Deploy customer-service and product-service
- [ ] Deploy Envoy gateway
- [ ] Verify all pods running: `kubectl get pods -n api-gateway-poc`
- [ ] Test via `kubectl port-forward` or LoadBalancer IP
- [ ] Update test configuration for Kubernetes endpoint
- [ ] Run integration tests against Kubernetes deployment

**2.5 - Documentation**
- [ ] Create `docs/kubernetes-deployment.md`:
  - [ ] Prerequisites (Docker Desktop, Kubernetes enabled)
  - [ ] Build instructions
  - [ ] Deployment instructions
  - [ ] Testing instructions
  - [ ] Access endpoints (port-forward, LoadBalancer)
- [ ] Update README.md with Kubernetes deployment section
- [ ] Create `docs/troubleshooting.md`:
  - [ ] Common Kubernetes issues
  - [ ] Pod debugging commands
  - [ ] Log inspection
  - [ ] Network troubleshooting

**Success Criteria:**
- [ ] All services running in Kubernetes namespace `api-gateway-poc`
- [ ] All pods in `Running` state
- [ ] Services accessible through Envoy gateway
- [ ] Redis caching working (verify in logs)
- [ ] Keycloak authentication working
- [ ] JWT validation working
- [ ] External authz (RBAC) working
- [ ] Tests passing against Kubernetes deployment (run `pytest -q` to validate)
- [ ] Both bash and PowerShell scripts working

---

### Phase 3: Kubernetes Gateway API Migration [FUTURE]

**Goal:** Replace direct Envoy deployment with Kubernetes Gateway API + Envoy Gateway

**Why This Matters:**
- **Current (Phase 2):** Envoy runs as a pod with static ConfigMap-based `envoy.yaml`
- **Target (Phase 3):** Use Kubernetes Gateway API CRDs (Gateway, HTTPRoute, SecurityPolicy)
- **Benefits:**
  - Declarative Kubernetes-native configuration
  - Dynamic updates without pod restarts
  - Standard API (portable across gateway implementations)
  - Better integration with Kubernetes ecosystem
  - Simplified management via kubectl

#### Tasks:

**3.1 - Install Envoy Gateway**
- [ ] Install Envoy Gateway operator to cluster
- [ ] Create GatewayClass resource
- [ ] Verify installation: `kubectl get pods -n envoy-gateway-system`

**3.2 - Migrate Envoy Config to Gateway API**
- [ ] Create Gateway resource (replaces envoy Deployment)
- [ ] Create HTTPRoute for customer-service (`/customers/*`)
- [ ] Create HTTPRoute for product-service (`/products/*`)
- [ ] Create HTTPRoute for authz-service (`/auth/*`)
- [ ] Create SecurityPolicy for JWT validation (Keycloak JWKS)
- [ ] Create SecurityPolicy for ext_authz (authz-service)
- [ ] Remove old Envoy Deployment and ConfigMap

**3.3 - Testing & Validation**
- [ ] Update test configuration for new gateway endpoint
- [ ] Test all routing paths
- [ ] Test authentication flow (JWT validation)
- [ ] Test authorization flow (RBAC via authz-service)
- [ ] Verify Redis caching still works
- [ ] Run full test suite (100+ tests)

**3.4 - Deployment Scripts**
- [ ] Create `deploy-k8s-phase3.sh` (bash)
- [ ] Create `deploy-k8s-phase3.ps1` (PowerShell)
- [ ] Update cleanup scripts for Gateway API resources

**3.5 - Documentation**
- [ ] Create `docs/gateway-api-migration.md`:
  - [ ] Gateway API concepts
  - [ ] Migration steps from Phase 2 to Phase 3
  - [ ] Gateway API resource reference
  - [ ] Troubleshooting Gateway API
- [ ] Update `docs/kubernetes-deployment.md` for Phase 3
- [ ] Update troubleshooting guide

**Success Criteria:**
- [ ] Envoy Gateway managing all traffic routing
- [ ] Gateway API resources (Gateway, HTTPRoute, SecurityPolicy) working
- [ ] JWT validation via SecurityPolicy
- [ ] External authz working via SecurityPolicy
- [ ] Tests passing (run `pytest -q` to validate)
- [ ] No direct Envoy Deployment (all via Gateway API CRDs)
- [ ] Can update routes without pod restarts

---

### Phase 4: Advanced Features [FUTURE] (Optional)

**Goal:** Add advanced Kubernetes-native features

**Possible Tasks:**
- [ ] Configure rate limiting using RateLimitPolicy
- [ ] Add retry and timeout policies
- [ ] Configure circuit breaking
- [ ] Add observability (Prometheus metrics, distributed tracing)
- [ ] Implement canary deployments
- [ ] Add NetworkPolicies for security
- [ ] Configure HorizontalPodAutoscaler
- [ ] Add liveness and readiness probes
- [ ] Configure resource requests and limits

---

## Development Workflow

### Phase 2 Development Flow

**Code Changes:**
1. Make changes to service code
2. Test locally with Docker Compose: `docker-compose up`
3. Run tests: `pytest tests/`

**Build & Deploy to Kubernetes:**
```bash
# Bash (Linux/Mac/WSL)
./scripts/bash/build-images.sh
./scripts/bash/deploy-k8s-phase2.sh
./scripts/bash/verify-deployment.sh
./scripts/bash/test-endpoints.sh

# PowerShell (Windows)
.\scripts\powershell\build-images.ps1
.\scripts\powershell\deploy-k8s-phase2.ps1
.\scripts\powershell\verify-deployment.ps1
.\scripts\powershell\test-endpoints.ps1
```

**Testing:**
```bash
# Run unit tests
pytest tests/unit/

# Run integration tests (update GATEWAY_BASE_URL for K8s)
pytest tests/integration/

# Check logs
kubectl logs -f deployment/envoy -n api-gateway-poc
kubectl logs -f deployment/authz-service -n api-gateway-poc
```

**Debugging:**
```bash
# Get pod status
kubectl get pods -n api-gateway-poc

# Describe pod
kubectl describe pod <pod-name> -n api-gateway-poc

# Port forward for testing
kubectl port-forward -n api-gateway-poc svc/envoy 8080:8080

# Access logs
kubectl logs -f <pod-name> -n api-gateway-poc

# Execute into pod
kubectl exec -it <pod-name> -n api-gateway-poc -- /bin/sh
```

**Commit:**
```bash
git add .
git commit -m "Your message"
git push origin feature/k8s-basic
```

---

## Prerequisites & Setup

### Required Software

- [x] Windows 11 (Development) / macOS (Development) / Linux (Deployment)
- [x] Git
- [x] Docker Desktop (with Kubernetes enabled)
- [x] Python 3.12
- [x] kubectl (usually installed with Docker Desktop)
- [x] pytest (for testing)
- [ ] (Optional) k9s for easier cluster management
- [ ] (Optional) Postman or similar for API testing

### Enabling Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Settings -> Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"
5. Wait for Kubernetes to start (green indicator)

### Verify Installation

```bash
# Check Docker
docker --version

# Check Kubernetes
kubectl version --client
kubectl cluster-info

# Check Python
python --version

# Check pip
pip --version
```

---

## Learning Resources

### Kubernetes
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

### Gateway API (Phase 3)
- [Kubernetes Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [Gateway API Concepts](https://gateway-api.sigs.k8s.io/concepts/api-overview/)

### Envoy Gateway (Phase 3)
- [Envoy Gateway Docs](https://gateway.envoyproxy.io/)
- [Envoy Gateway Tasks](https://gateway.envoyproxy.io/latest/tasks/)
- [Envoy Gateway Security](https://gateway.envoyproxy.io/latest/tasks/security/)

### FastAPI
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [FastAPI in Containers](https://fastapi.tiangolo.com/deployment/docker/)

### Testing
- [pytest Documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)

---

## Success Metrics

### Phase 1 [COMPLETE]
- [x] All services running in Docker Compose
- [x] Envoy gateway routing working
- [x] JWT validation working
- [x] External authz (RBAC) working
- [x] Redis caching working

### Phase 2 (Current Target)
- [ ] All services running in Kubernetes
- [ ] All pods in `Running` state
- [ ] Services accessible via Envoy gateway
- [ ] JWT validation working
- [ ] External authz working
- [ ] Redis caching working
- [ ] Tests passing against Kubernetes (verify with `pytest -q`)
- [ ] Both bash and PowerShell scripts working

### Phase 3 (Future)
- [ ] Envoy Gateway operator installed
- [ ] Gateway API resources created and working
- [ ] All traffic routed through Gateway API
- [ ] JWT validation via SecurityPolicy
- [ ] External authz via SecurityPolicy
- [ ] Tests passing (verify with `pytest -q`)
- [ ] No direct Envoy Deployment
- [ ] Can update routes without pod restarts

---

## Notes & Decisions

### Why Docker Desktop Kubernetes?
- Integrated with Windows 11 and macOS
- Easy to start/stop
- Good for local development and POC
- No additional infrastructure needed
- Cross-platform development support

### Why Phase 2 Before Phase 3?
- Validate Kubernetes deployment works with minimal changes
- Learn Kubernetes fundamentals first
- Easier debugging (familiar Envoy configuration)
- Gateway API is additive, not replacing fundamentals

### Why Both Bash and PowerShell Scripts?
- **Development Team:** Mixed Windows and macOS users
- **Deployment Environment:** Linux
- **Bash:** Works on Linux, macOS, WSL, Git Bash
- **PowerShell:** Native Windows experience
- **Maintenance:** Keep scripts in sync (same logic, different syntax)

### Why Namespace `api-gateway-poc`?
- Matches Keycloak realm name
- Clear purpose indication
- Easy to identify POC resources
- Simple to clean up: `kubectl delete namespace api-gateway-poc`

### Why Keep Tests Through Gateway?
- Tests real-world user flow
- Validates entire stack (gateway + services)
- Catches routing and auth issues
- Same tests work for Docker Compose and Kubernetes

### Why Minimal Documentation?
- Focus on practical deployment guides
- Avoid documentation maintenance burden
- Code and scripts are self-documenting
- Comprehensive docs after POC validation

---

## Troubleshooting

### Docker Desktop Kubernetes Issues

**Kubernetes not starting:**
- Increase Docker Desktop memory (Settings -> Resources -> Memory: 4GB+)
- Reset Kubernetes cluster (Settings -> Kubernetes -> Reset)
- Restart Docker Desktop

**Images not found in Kubernetes:**
- Docker Desktop shares images automatically
- Verify with `docker images`
- Use `imagePullPolicy: IfNotPresent` in deployments
- Ensure image name matches exactly (including tags)

### Kubernetes Deployment Issues

**Pods not starting:**
```bash
# Check pod status
kubectl get pods -n api-gateway-poc

# Describe pod for events
kubectl describe pod <pod-name> -n api-gateway-poc

# Check logs
kubectl logs <pod-name> -n api-gateway-poc
```

**Services not accessible:**
```bash
# Check service endpoints
kubectl get endpoints -n api-gateway-poc

# Verify service configuration
kubectl describe service <service-name> -n api-gateway-poc

# Test service connectivity from another pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n api-gateway-poc -- curl http://<service-name>:8000/health
```

**ConfigMap/Secret not loading:**
```bash
# Verify ConfigMap exists
kubectl get configmap -n api-gateway-poc

# View ConfigMap contents
kubectl describe configmap <configmap-name> -n api-gateway-poc

# Verify Secret exists
kubectl get secret -n api-gateway-poc
```

### Common Application Issues

**Keycloak not ready:**
- Check health endpoint: `kubectl logs -f deployment/keycloak -n api-gateway-poc`
- Wait for "Keycloak ... started" in logs
- Health check takes ~60 seconds on first start

**Redis connection failed:**
- Verify Redis pod running: `kubectl get pods -n api-gateway-poc | grep redis`
- Check authz-service logs for connection errors
- Verify REDIS_URL environment variable

**JWT validation failing:**
- Verify Keycloak JWKS endpoint accessible from Envoy
- Check Envoy logs: `kubectl logs -f deployment/envoy -n api-gateway-poc`
- Verify Keycloak service DNS resolution

**External authz failing:**
- Check authz-service logs: `kubectl logs -f deployment/authz-service -n api-gateway-poc`
- Verify authz-service endpoint accessible from Envoy
- Check Redis caching logs (cache HIT/MISS)

---

## Next Steps

### Immediate (Phase 2)
1. [ ] Create Kubernetes manifests (namespace, configmaps, secrets, deployments, services)
2. [ ] Create deployment scripts (bash + PowerShell)
3. [ ] Build and deploy to Kubernetes
4. [ ] Verify all pods running
5. [ ] Run integration tests
6. [ ] Document deployment process

### After Phase 2
1. [ ] Review Phase 2 learnings
2. [ ] Plan Phase 3 migration to Gateway API
3. [ ] Install Envoy Gateway
4. [ ] Create Gateway API resources
5. [ ] Migrate traffic to Gateway API
6. [ ] Validate and test

---

**Last Updated:** 2024-01-XX (To be updated)  
**Status:** Phase 2 - Kubernetes Migration (In Progress)  
**Current Phase:** Phase 2  
**Branch:** `feature/k8s-basic`
