# EnvoyK8SPOC - Project Plan

## Project Overview

**Name:** EnvoyK8SPOC (Envoy Gateway + Kubernetes Proof of Concept)  
**Purpose:** Learning and demonstrating Envoy Gateway with FastAPI microservices on Kubernetes  
**Environment:** Windows 11, Docker Desktop with Kubernetes, Python 3.12  
**Type:** Proof of Concept & Learning Project

---

## Objectives

1. Deploy two FastAPI microservices (customer-service, product-service) to Kubernetes
2. Implement Envoy Gateway using Kubernetes Gateway API for HTTP routing
3. Configure rate limiting using Envoy Gateway features
4. **(Future/Deferred)** Integrate Keycloak for authentication and role-based authorization

---

## Architecture

### Components

```
???????????????????????????????????????????????????????????
?         Envoy Gateway           ?
?  (Kubernetes Gateway API)        ?
???????????????????????????????????????????????????????????
      ?          ?
           ?      ?
      ????????????????????  ???????????????????
      ? customer-service ?  ? product-service  ?
      ?    (FastAPI)   ?  ?    (FastAPI)     ?
      ?  In-memory data  ??  In-memory data  ?
      ????????????????????  ????????????????????
```

### Technology Stack

- **Container Runtime:** Docker Desktop
- **Orchestration:** Kubernetes (Docker Desktop built-in)
- **API Gateway:** Envoy Gateway (with Gateway API)
- **Backend Services:** FastAPI (Python 3.12)
- **Authentication (Phase 3):** Keycloak
- **Version Control:** Git + GitHub (HTTPS)

---

## Project Structure

```
EnvoyK8SPOC/
??? README.md               # Project overview and quick start
??? PROJECT_PLAN.md                # This file
??? docs/   # Additional documentation
?   ??? setup-guide.md          # Environment setup instructions
?   ??? architecture.md     # Detailed architecture
?   ??? lessons-learned.md # Learning notes
??? services/
?   ??? customer-service/
?   ?   ??? app/
? ?   ?   ??? __init__.py
?   ?   ?   ??? main.py       # FastAPI application
?   ? ?   ??? models.py   # Data models
?   ???? Dockerfile
?   ?   ??? requirements.txt
?   ?   ??? README.md
?   ??? product-service/
?       ??? app/
?       ?   ??? __init__.py
?       ?   ??? main.py      # FastAPI application
?       ? ??? models.py # Data models
?       ??? Dockerfile
?       ??? requirements.txt
?       ??? README.md
??? kubernetes/
?   ??? 00-namespace/
?   ?   ??? namespace.yaml
?   ??? 01-envoy-gateway/
?   ?   ??? install.yaml     # Envoy Gateway installation
?   ???? gateway-class.yaml         # GatewayClass resource
?   ??? 02-services/
?   ? ??? customer-deployment.yaml
?   ?   ??? customer-service.yaml
?   ?   ??? product-deployment.yaml
?   ?   ??? product-service.yaml
?   ??? 03-gateway/
?   ?   ??? gateway.yaml       # Gateway resource
?   ?   ??? http-routes.yaml           # HTTPRoute resources
?   ??? 04-rate-limiting/
?   ?   ??? rate-limit-policy.yaml     # Rate limiting configuration
?   ??? 05-auth/ # For future Keycloak integration
?       ??? README.md
??? scripts/
?   ??? build-images.ps1         # Build Docker images
?   ??? deploy-all.ps1     # Deploy everything to K8s
?   ??? cleanup.ps1          # Remove all resources
?   ??? test-endpoints.ps1             # Test API endpoints
??? .gitignore

```

---

## Implementation Phases

### Phase 0: Environment Setup ? (Completed)

- [x] Create GitHub repository
- [x] Initialize Git repository locally
- [x] Verify Docker Desktop installation
- [x] Verify Kubernetes is enabled in Docker Desktop
- [x] Verify Python 3.12 installation

**Next Steps:**
- [ ] Enable Kubernetes in Docker Desktop (if not already enabled)
- [ ] Verify kubectl is installed and configured
- [ ] Install Envoy Gateway

### Phase 1: Basic Service Deployment (Week 1)

**Goal:** Deploy FastAPI services to Kubernetes without gateway

#### Tasks:
1. **Create customer-service**
   - [ ] Set up FastAPI application structure
   - [ ] Create sample customer endpoints (GET /customers, GET /customers/{id})
   - [ ] Add in-memory data store
   - [ ] Write Dockerfile
 - [ ] Create requirements.txt
   - [ ] Test locally with `uvicorn`

2. **Create product-service**
   - [ ] Set up FastAPI application structure
   - [ ] Create sample product endpoints (GET /products, GET /products/{id})
   - [ ] Add in-memory data store
   - [ ] Write Dockerfile
   - [ ] Create requirements.txt
   - [ ] Test locally with `uvicorn`

3. **Kubernetes Resources**
   - [ ] Create namespace (e.g., `envoy-poc`)
   - [ ] Write Deployment manifests for both services
   - [ ] Write Service manifests (ClusterIP)
   - [ ] Build Docker images
   - [ ] Load images into Docker Desktop Kubernetes
   - [ ] Deploy services
   - [ ] Test services using port-forwarding

**Success Criteria:**
- Both services respond to HTTP requests via `kubectl port-forward`
- Services return sample data correctly

---

### Phase 2: Envoy Gateway + HTTP Routing (Week 2)

**Goal:** Route traffic through Envoy Gateway using Kubernetes Gateway API

#### Tasks:
1. **Install Envoy Gateway**
   - [ ] Apply Envoy Gateway manifests to cluster
   - [ ] Verify installation
   - [ ] Create GatewayClass resource

2. **Configure Gateway API Resources**
   - [ ] Create Gateway resource
   - [ ] Create HTTPRoute for customer-service (`/customers/*`)
   - [ ] Create HTTPRoute for product-service (`/products/*`)
   - [ ] Configure path-based routing

3. **Testing**
   - [ ] Access services through Gateway
   - [ ] Verify routing works correctly
   - [ ] Test different HTTP methods (GET, POST if implemented)
   - [ ] Document Gateway IP/hostname access

**Success Criteria:**
- Traffic routes correctly through Envoy Gateway
- `/customers` routes to customer-service
- `/products` routes to product-service
- No direct service access needed (all via Gateway)

---

### Phase 3: Rate Limiting (Week 3)

**Goal:** Implement rate limiting using Envoy Gateway features

#### Tasks:
1. **Configure Rate Limiting**
   - [ ] Research Envoy Gateway rate limiting options
   - [ ] Create RateLimitPolicy or equivalent CRD
   - [ ] Apply different limits per service
   - [ ] Configure global vs per-route limits

2. **Testing**
   - [ ] Test rate limiting with automated requests
   - [ ] Verify 429 responses when limits exceeded
   - [ ] Test rate limit headers
   - [ ] Document behavior

**Success Criteria:**
- Rate limits enforced correctly
- Proper HTTP 429 responses returned
- Rate limit behavior documented

---

### Phase 4: Keycloak Authentication & Authorization (Deferred)

**Goal:** Secure services with Keycloak-based authentication and role-based access

#### Tasks (To be detailed later):
1. **Keycloak Setup**
   - [ ] Deploy Keycloak to Kubernetes or run separately
   - [ ] Configure realm, clients, roles
   - [ ] Create test users with different roles

2. **Envoy Integration**
   - [ ] Configure JWT validation
   - [ ] Implement role-based routing/access
   - [ ] Add authentication to HTTPRoutes

3. **Testing**
   - [ ] Test with valid/invalid tokens
   - [ ] Test role-based access control
   - [ ] Document authentication flow

---

## Development Workflow

### Daily Development Flow

1. **Code Changes**
   - Make changes to service code
   - Test locally with `uvicorn app.main:app --reload`

2. **Build & Deploy**
   - Build Docker image: `docker build -t <service-name>:latest .`
   - Load to K8s: `docker save <service-name>:latest | docker load` (already available in Docker Desktop)
   - Update deployment: `kubectl rollout restart deployment/<service-name>`

3. **Testing**
   - Use `kubectl port-forward` or Gateway endpoint
   - Run test scripts
   - Check logs: `kubectl logs -f deployment/<service-name>`

4. **Commit**
   - Commit working changes
   - Push to GitHub

---

## Prerequisites & Setup

### Required Software

- [x] Windows 11
- [x] Git
- [x] Docker Desktop (with Kubernetes enabled)
- [x] Python 3.12
- [ ] kubectl (usually installed with Docker Desktop)
- [ ] (Optional) k9s for easier cluster management
- [ ] (Optional) Postman or similar for API testing

### Enabling Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Settings ? Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"
5. Wait for Kubernetes to start (green indicator)

### Verify Installation

```powershell
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

### Install Envoy Gateway

```powershell
# Install Envoy Gateway (check latest version at https://gateway.envoyproxy.io/)
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v0.6.0/install.yaml

# Verify installation
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
```

---

## Learning Resources

### Gateway API
- [Kubernetes Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [Gateway API Concepts](https://gateway-api.sigs.k8s.io/concepts/api-overview/)

### Envoy Gateway
- [Envoy Gateway Docs](https://gateway.envoyproxy.io/)
- [Envoy Gateway Tasks](https://gateway.envoyproxy.io/latest/tasks/)
- [Rate Limiting Guide](https://gateway.envoyproxy.io/latest/tasks/traffic/rate-limiting/)

### FastAPI
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [FastAPI in Containers](https://fastapi.tiangolo.com/deployment/docker/)

### Kubernetes
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

## Success Metrics

### Phase 1
- [ ] Both services running in Kubernetes
- [ ] Services accessible via port-forward
- [ ] All endpoints returning correct data

### Phase 2
- [ ] Envoy Gateway installed and running
- [ ] Gateway API resources created
- [ ] All traffic routed through Gateway
- [ ] Path-based routing working

### Phase 3
- [ ] Rate limiting configured
- [ ] Rate limits enforced
- [ ] Proper error responses

### Phase 4 (Future)
- [ ] Keycloak integrated
- [ ] JWT validation working
- [ ] Role-based access control functioning

---

## Notes & Decisions

### Why Docker Desktop Kubernetes?
- Integrated with Windows 11
- Easy to start/stop
- Good for local development
- No additional VM management

### Why Envoy Gateway?
- Native Kubernetes Gateway API support
- Modern, declarative configuration
- Powerful traffic management features
- Active development and community

### Why In-Memory Data?
- Simplified POC scope
- Focus on routing and gateway features
- Easy to test and demonstrate
- Can migrate to database later if needed

### Python Virtual Environments
**Note:** Consider using Python virtual environments (`venv`) to isolate dependencies:
```powershell
# In each service directory
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

This prevents dependency conflicts between projects.

---

## Troubleshooting

### Common Issues

**Kubernetes not starting in Docker Desktop**
- Increase Docker Desktop memory (Settings ? Resources ? Memory: 4GB+)
- Reset Kubernetes cluster (Settings ? Kubernetes ? Reset)

**Images not found in Kubernetes**
- Docker Desktop shares images automatically; no need to push
- Verify with `docker images`
- Use `imagePullPolicy: Never` or `IfNotPresent` in deployments

**Services not accessible**
- Check pod status: `kubectl get pods`
- Check logs: `kubectl logs <pod-name>`
- Verify service endpoints: `kubectl get endpoints`

**Gateway not routing**
- Check Gateway status: `kubectl get gateway -n <namespace>`
- Check HTTPRoute status: `kubectl get httproute -n <namespace>`
- Check Envoy Gateway logs: `kubectl logs -n envoy-gateway-system deployment/envoy-gateway`

---

## Next Steps

1. Review and approve this plan
2. Create project structure (folders)
3. Verify Kubernetes is running in Docker Desktop
4. Install Envoy Gateway
5. Begin Phase 1: Create customer-service

---

## Questions & Clarifications Needed

1. **Docker Image Strategy:** Should images be:
   - Built locally and used directly (recommended for POC)
   - Pushed to Docker Hub
   - Pushed to a local registry

2. **Python Virtual Environment:** Should we use venv for each service?

3. **Existing Docker POC:** What files/structure can be reused from your previous Docker POC?

4. **Testing Approach:** Do you want automated tests (pytest) or manual testing is sufficient?

5. **Documentation Level:** Should I create detailed step-by-step guides in `/docs`?

---

**Last Updated:** [Date created]  
**Status:** Planning Phase  
**Current Phase:** Phase 0 (Environment Setup)
