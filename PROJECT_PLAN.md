# EnvoyK8SPOC - Project Plan

## Project Overview

**Name:** EnvoyK8SPOC (Envoy Gateway + Kubernetes Proof of Concept)  
**Purpose:** Learning and demonstrating Envoy Gateway with FastAPI microservices on Kubernetes  
**Dev Environment:** Windows 11/MacOS, Docker Desktop with Kubernetes, Python 3.12  
**Type:** Proof of Concept & Learning Project

---

## Objectives

1. Deploy two FastAPI microservices (customer-service, product-service) to Kubernetes
2. Implement Envoy Gateway using Kubernetes Gateway API for HTTP routing
3. Integrate Keycloak for authentication and role-based authorization
4. Configure rate limiting using Envoy Gateway features

---

## Architecture

### Components

```
+----------------------------------+
|  Envoy Gateway                   |
|  (Kubernetes Gateway API)        |
+----------------------------------+
      |                    |
      |                    |
      v                    v
+------------------+  +------------------+
| customer-service |  | product-service  |
|    (FastAPI)     |  |    (FastAPI)     |
|  In-memory data  |  |  In-memory data  |
+------------------+  +------------------+
```

### Technology Stack for Development

- **Container Runtime:** Docker Desktop
- **Orchestration:** Kubernetes (Docker Desktop built-in)
- **API Gateway:** Envoy Gateway (with Gateway API)
- **Backend Services:** FastAPI (Python 3.12)
- **Authentication (Phase 3):** Keycloak
- **Rate Limiting (Phase 4):** Envoy Gateway
- **Version Control:** Git + GitHub (HTTPS)

---

## Project Structure

```
EnvoyK8SPOC/
|-- README.md
|-- PROJECT_PLAN.md
|-- .gitignore
|-- .copilot-instructions.md
|-- docs/
|   |-- api/
|   |   |-- api-generation-guide.md
|   |   |-- customer-service-api.md
|   |   |-- product-service-api.md
|   |-- architecture/
|   |   |-- authn-authz-flow.md
|   |   |-- system-architecture.md
|   |-- demo/
|   |   |-- demo-script.md
|   |-- development/
|   |   |-- quick-reference.md
|   |   |-- setup-guide.md
|   |   |-- troubleshooting.md
|   |-- security/
|   |   |-- quick-reference.md
|   |-- test/
|   |   |-- test-utilities.md
|-- services/
|   |-- customer-service/
|   |   |-- app/
|   |   |   |-- __init__.py
|   |   |   |-- customer_data_access.py
|   |   |   |-- customer_model.py
|   |   |   |-- main.py
|   |   |-- Dockerfile
|   |   |-- requirements.txt
|   |   |-- .dockerignore
|   |-- product-service/
|   |   |-- app/
|   |   |   |-- __init__.py
|   |   |   |-- main.py
|   |   |   |-- product_data_access.py
|   |   |   |-- product_model.py
|   |   |-- Dockerfile
|   |   |-- requirements.txt
|   |   |-- .dockerignore
|   |-- shared/
|   |   |-- __init__.py
|   |   |-- auth.py
|   |   |-- common.py
|-- tests/
|   |-- unit/
|   |   |-- __init__.py
|   |   |-- conftest.py
|   |   |-- requirements.txt
|   |   |-- test_customer_service.py
|   |   |-- test_product_service.py
|   |-- integration/
|   |   |-- __init__.py
|   |   |-- conftest.py
|   |   |-- requirements.txt
|   |   |-- test_gateway_routing.py
|-- kubernetes/
|   |-- 00-namespace/
|   |   |-- namespace.yaml
|   |-- 01-envoy-gateway/
|   |   |-- install.yaml
|   |   |-- gateway-class.yaml
|   |-- 02-services/
|   |   |-- customer-deployment.yaml
|   |   |-- customer-service.yaml
|   |   |-- product-deployment.yaml
|   |   |-- product-service.yaml
|   |-- 03-gateway/
|   |   |-- gateway.yaml
|   ||-- http-routes.yaml
|   |-- 04-keycloak/
|   |   |-- keycloak-deployment.yaml
|   |   |-- auth-policy.yaml
|   |-- 05-rate-limiting/
|   |  |-- rate-limit-policy.yaml
|-- scripts/
|   |-- build-images.sh
|   |-- deploy-all.sh
|   |-- cleanup.sh
|   |-- test-endpoints.sh
|   |-- README.md
```

---

## Implementation Phases

### Phase 0: Environment Setup (Completed)

- [x] Create GitHub repository
- [x] Initialize Git repository locally
- [x] Verify Docker Desktop installation
- [x] Verify Kubernetes is enabled in Docker Desktop
- [x] Verify Python 3.12 installation

**Next Steps:**
- [ ] Enable Kubernetes in Docker Desktop (if not already enabled)
- [ ] Verify kubectl is installed and configured
- [ ] Install Envoy Gateway
- [x] Create .gitignore file
- [x] Create .copilot-instructions.md file

### Phase 1: Basic Service Deployment

**Goal:** Deploy FastAPI services to Kubernetes without gateway

#### Tasks:
1. **Create customer-service**
   - [ ] Set up FastAPI application structure
   - [ ] Create sample customer endpoints (GET /customers, GET /customers/{id})
   - [ ] Add in-memory data store with Data Access Layer
   - [ ] Write Dockerfile
   - [ ] Create requirements.txt
   - [ ] Test locally with `uvicorn`

2. **Create product-service**
   - [ ] Set up FastAPI application structure
   - [ ] Create sample product endpoints (GET /products, GET /products/{id})
   - [ ] Add in-memory data store with Data Access Layer
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

4. **Unit Testing**
   - [ ] Create pytest configuration
   - [ ] Write unit tests for customer-service
   - [ ] Write unit tests for product-service
   - [ ] Verify all tests pass

**Success Criteria:**
- Both services respond to HTTP requests via `kubectl port-forward`
- Services return sample data correctly
- All unit tests pass

---

### Phase 2: Envoy Gateway + HTTP Routing

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
   - [ ] Create integration tests for gateway routing

**Success Criteria:**
- Traffic routes correctly through Envoy Gateway
- `/customers` routes to customer-service
- `/products` routes to product-service
- No direct service access needed (all via Gateway)
- Integration tests pass

---

### Phase 3: Keycloak Authentication & Authorization

**Goal:** Secure services with Keycloak-based authentication and role-based access

#### Tasks:
1. **Keycloak Setup**
   - [ ] Deploy Keycloak to Kubernetes or run separately
   - [ ] Configure realm, clients, roles
   - [ ] Create test users with different roles

2. **Envoy Integration**
   - [ ] Configure JWT validation
   - [ ] Implement role-based routing/access
   - [ ] Add authentication to HTTPRoutes
   - [ ] Update services to include authorization checks

3. **Testing**
   - [ ] Test with valid/invalid tokens
   - [ ] Test role-based access control
   - [ ] Document authentication flow
   - [ ] Update integration tests for authenticated requests

**Success Criteria:**
- Keycloak integrated with Envoy Gateway
- JWT validation working
- Role-based access control functioning
- All tests pass with authentication

---

### Phase 4: Rate Limiting

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
   - [ ] Create integration tests for rate limiting

**Success Criteria:**
- Rate limits enforced correctly
- Proper HTTP 429 responses returned
- Rate limit behavior documented
- Integration tests validate rate limiting

---

## Development Workflow

### Daily Development Flow

1. **Code Changes**
   - Make changes to service code
   - Test locally with `uvicorn app.main:app --reload`

2. **Build & Deploy**
   - Build Docker image: `docker build -t <service-name>:latest .`
   - Load to K8s: Images are already available in Docker Desktop
   - Update deployment: `kubectl rollout restart deployment/<service-name>`

3. **Testing**
   - Run unit tests: `pytest tests/unit/`
   - Run integration tests: `pytest tests/integration/`
   - Use `kubectl port-forward` or Gateway endpoint
   - Run test scripts
   - Check logs: `kubectl logs -f deployment/<service-name>`

4. **Commit**
   - Commit working changes
   - Push to GitHub

---

## Prerequisites & Setup

### Required Software

- [x] Windows 11 (Development) / macOS (Team member)
- [x] Git
- [x] Docker Desktop (with Kubernetes enabled)
- [x] Python 3.12
- [ ] kubectl (usually installed with Docker Desktop)
- [ ] pytest (for testing)
- [ ] (Optional) k9s for easier cluster management
- [ ] (Optional) Postman or similar for API testing

### Deployment Environment

- **Target OS:** Linux-based Kubernetes cluster
- **Development:** Windows 11 / macOS with Docker Desktop
- **POC Deployment:** Docker Desktop Kubernetes (local)
- **Future Production:** Linux Kubernetes distribution (TBD)

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

### Install Envoy Gateway

```bash
# Install Envoy Gateway (check latest version at https://gateway.envoyproxy.io/)
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v0.6.0/install.yaml

# Verify installation
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass
```

---

## Python Development Best Practices

### Virtual Environment Strategy

For this POC, we will use Python virtual environments (`venv`) for each service to isolate dependencies:

```bash
# Windows (using WSL, Git Bash, or PowerShell)
cd services/customer-service
python -m venv venv

# Activate on Windows PowerShell
.\venv\Scripts\Activate.ps1

# Activate on Windows WSL/Git Bash
source venv/bin/activate

# macOS/Linux
cd services/customer-service
python3 -m venv venv
source venv/bin/activate

# Install dependencies (all platforms)
pip install -r requirements.txt
```

### Why venv for this project:
- Standard library tool (no additional dependencies)
- Simple and straightforward for POC
- Isolates dependencies between services
- Cross-platform compatible (Windows/macOS/Linux)
- Easy for team members to replicate

### Why Bash Scripts?
- Cross-platform (Windows WSL/Git Bash, macOS, Linux)
- Single maintenance point (no platform-specific versions)
- Industry standard for Kubernetes/Docker tooling
- CI/CD ready (GitHub Actions, GitLab CI, etc.)
- Native experience for all team members

### Deployment Target
- **Development:** Docker Desktop on Windows 11 / macOS
- **POC Deployment:** Docker Desktop Kubernetes
- **Future Production:** Linux-based Kubernetes (distribution TBD)

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

### Testing
- [pytest Documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)

---

## Success Metrics

### Phase 1
- [ ] Both services running in Kubernetes
- [ ] Services accessible via port-forward
- [ ] All endpoints returning correct data
- [ ] Unit tests passing

### Phase 2
- [ ] Envoy Gateway installed and running
- [ ] Gateway API resources created
- [ ] All traffic routed through Gateway
- [ ] Path-based routing working
- [ ] Integration tests passing

### Phase 3
- [ ] Keycloak integrated
- [ ] JWT validation working
- [ ] Role-based access control functioning
- [ ] Authentication tests passing

### Phase 4
- [ ] Rate limiting configured
- [ ] Rate limits enforced
- [ ] Proper error responses
- [ ] Rate limiting tests passing

---

## Notes & Decisions

### Why Docker Desktop Kubernetes?
- Integrated with Windows 11 and macOS
- Easy to start/stop
- Good for local development
- No additional VM management
- Cross-platform development support

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

### Why Python venv?
- Standard library tool (no extra dependencies)
- Simple and straightforward
- Cross-platform compatible
- Industry best practice for simple projects
- Easy for team members to replicate

### Why Bash Scripts?
- Cross-platform (Windows WSL/Git Bash, macOS, Linux)
- Single maintenance point (no platform-specific versions)
- Industry standard for Kubernetes/Docker tooling
- CI/CD ready (GitHub Actions, GitLab CI, etc.)
- Native experience for all team members

### Deployment Target
- **Development:** Docker Desktop on Windows 11 / macOS
- **POC Deployment:** Docker Desktop Kubernetes
- **Future Production:** Linux-based Kubernetes (distribution TBD)

---

## Troubleshooting

### Common Issues

**Kubernetes not starting in Docker Desktop**
- Increase Docker Desktop memory (Settings -> Resources -> Memory: 4GB+)
- Reset Kubernetes cluster (Settings -> Kubernetes -> Reset)

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

1. Create .gitignore file
2. Create .copilot-instructions.md file
3. Update project structure manually
4. Create project structure (folders)
5. Verify Kubernetes is running in Docker Desktop
6. Install Envoy Gateway
7. Begin Phase 1: Create customer-service

---

## Answers to Questions

1. **Docker Image Strategy:** Built locally and used directly (recommended for POC)

2. **Python Virtual Environment:** Using `venv` (standard library) for simplicity and cross-platform compatibility

3. **Existing Docker POC:** Project structure will reflect existing service organization for customer-service and product-service, plus Tests folder with unit and integration tests

4. **Testing Approach:** Using pytest for both unit and integration tests

5. **Documentation Level:** See updated project structure for docs organization

---

**Last Updated:** [To be updated]  
**Status:** Planning Phase  
**Current Phase:** Phase 0 (Environment Setup)
