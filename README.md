# EnvoyK8SPOC

**Envoy Gateway + Kubernetes Proof of Concept**

A learning project demonstrating the migration from Docker Compose to Kubernetes-native architecture with Envoy Gateway, featuring JWT authentication, role-based access control (RBAC), and the Kubernetes Gateway API.

## 📋 Project Overview

This project showcases a complete microservices architecture evolution across three phases:

- **Phase 1 (Complete):** Docker Compose with Envoy Proxy, Keycloak, and RBAC ✅
- **Phase 2 (Complete):** Kubernetes deployment with direct Envoy ✅
- **Phase 3 (Ready):** Kubernetes Gateway API with Envoy Gateway 🚀

## 🏗️ Architecture

### Phase 3: Gateway API (Current)

```
Kubernetes Gateway API
│
├── Envoy Gateway Operator (envoy-gateway-system)
│   └── Manages Gateway resources
│
├── api-gateway-poc Namespace
│   ├── Gateway (api-gateway)
│   │   ├── HTTP Listener :8080
│   │   └── Auto-created Envoy Proxy (data plane runs in `envoy-gateway-system`)
│   │
│   ├── HTTPRoutes
│   │   ├── customer-route (/customers/*)
│   │   ├── product-route (/products/*)
│   │   ├── auth-me-route (/auth/me)
│   │   └── keycloak-route (/auth/*)
│   │
│   ├── SecurityPolicies
│   │   ├── JWT Authentication (Keycloak JWKS)
│   │   └── External Authorization (authz-service)
│   │
│   └── Backend Services
│       ├── Keycloak (IAM) :8180
│       ├── Redis (Cache)
│       ├── authz-service (ext_authz + RBAC)
│       ├── customer-service :8000
│       └── product-service :8000
```

### Key Features

- ✅ **JWT Authentication** via Keycloak (OpenID Connect)
- ✅ **Role-Based Access Control (RBAC)** via external authz service
- ✅ **Redis Caching** for role lookups (5-minute TTL)
- ✅ **Kubernetes Gateway API** for declarative routing
- ✅ **Dynamic Configuration** without pod restarts
- ✅ **Standard API** portable across gateway implementations
- ✅ **Test suite:** unit + integration tests (see `tests/` for current count)

## 🚀 Quick Start

### Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl (installed with Docker Desktop)
- Python 3.12 (for tests)
- Git

### Phase 3 Deployment

**1. Install Envoy Gateway (one-time):**

```bash
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

**2. Build images:**

```bash
# Linux/Mac/WSL
cd scripts/bash
./build-images.sh

# Windows PowerShell
cd scripts\powershell
.\build-images.ps1
```

**3. Deploy Phase 3:**

```bash
# Linux/Mac/WSL
./deploy-k8s-phase3.sh

# Windows PowerShell
.\deploy-k8s-phase3.ps1
```

**4. Verify and test:**

```bash
# Verify deployment
./verify-deployment.sh  # or .ps1 on Windows

# Test endpoints
./test-endpoints.sh  # or .ps1 on Windows
```

### Access Services

- **API Gateway:** http://localhost:8080
- **Keycloak Admin:** http://localhost:8080/auth (admin/admin)

### Test API (development example using `test-client`)

> Use the public `test-client` for quick local testing. For CI/automation prefer a confidential client with a secret or a service account flow.

```bash
# Get token (development public client)
TOKEN=$(curl -s -X POST "http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" | jq -r '.access_token')

# Test protected endpoint
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/customers
```

## 📦 Project Structure

```
EnvoyK8SPOC/
├── services/                      # Microservices
│   ├── customer-service/          # Customer API
│   ├── product-service/           # Product API
│   ├── authz-service/             # External authz + RBAC
│   ├── keycloak/                  # IAM (Keycloak + realm config)
│   ├── gateway/                   # Envoy Dockerfile (Phase 2)
│   └── shared/                    # Common utilities
│
├── kubernetes/                    # Kubernetes manifests
│   ├── 00-namespace/              # Namespace
│   ├── 01-config/                 # ConfigMaps & Secrets
│   ├── 02-storage/                # PersistentVolumeClaims
│   ├── 03-data/                   # Redis
│   ├── 04-iam/                    # Keycloak
│   ├── 05-authz/                  # Authorization service
│   ├── 06-services/               # Backend services
│   ├── 07-envoy-gateway/          # Phase 2: Direct Envoy
│   └── 08-gateway-api/            # Phase 3: Gateway API ⭐
│       ├── 01-gatewayclass.yaml
│       ├── 02-gateway.yaml
│       ├── 03-httproute-customer.yaml
│       ├── 04-httproute-product.yaml
│       ├── 05-httproute-auth-me.yaml
│       ├── 06-httproute-keycloak.yaml
│       ├── 07-securitypolicy-jwt.yaml
│       └── 08-securitypolicy-extauth.yaml
│
├── scripts/                       # Deployment automation
│   ├── bash/                      # Linux/Mac/WSL scripts
│   │   ├── build-images.sh
│   │   ├── deploy-k8s-phase2.sh
│   │   ├── deploy-k8s-phase3.sh   # Phase 3 deployment ⭐
│   │   ├── cleanup-k8s.sh
│   │   ├── verify-deployment.sh
│   │   └── test-endpoints.sh
│   └── powershell/                # Windows scripts
│       ├── build-images.ps1
│       ├── deploy-k8s-phase2.ps1
│       ├── deploy-k8s-phase3.ps1  # Phase 3 deployment ⭐
│       ├── cleanup-k8s.ps1
│       ├── verify-deployment.ps1
│       └── test-endpoints.ps1
│
├── tests/                         # Test suite (100+ tests)
│   ├── unit/                      # Unit tests
│   └── integration/               # Integration tests
│
├── docs/                          # Documentation
│   ├── kubernetes-deployment.md   # Phase 2 & 3 deployment guide
│   ├── gateway-api-migration.md   # Phase 3 migration guide ⭐
│   └── troubleshooting.md
│
├── docker-compose.yml             # Phase 1 reference
├── project-plan.md                # Full project roadmap
└── README.md                      # This file
```

## 📚 Documentation

- **[Kubernetes Deployment Guide](docs/kubernetes-deployment.md)** - Complete deployment instructions for Phase 2 & 3
- **[Gateway API Migration Guide](docs/gateway-api-migration.md)** - Phase 3 migration details
- **[Project Plan](project-plan.md)** - Full project roadmap and learning objectives
- **[Gateway API Resources](kubernetes/08-gateway-api/README.md)** - Gateway API resource reference
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Port mappings](docs/port-mappings.md)** - Cluster and docker-compose port mappings

> Note: SecurityPolicy filenames and Gateways can change as the CRD/layout evolves — check `kubernetes/08-gateway-api/` for current filenames and exact resource names.

## 🔄 Phase Evolution

### Phase 1: Docker Compose ✅
- **Status:** Complete
- **Gateway:** Envoy Proxy with static config
- **Deployment:** `docker-compose up`
- **Learning:** Microservices fundamentals, Envoy filters, JWT/RBAC

### Phase 2: Kubernetes (Direct Envoy) ✅
- **Status:** Complete
- **Gateway:** Envoy Deployment with ConfigMap
- **Deployment:** `kubectl apply` + manual Envoy management
- **Learning:** Kubernetes basics, Services, Deployments, ConfigMaps

### Phase 3: Gateway API 🚀
- **Status:** Ready for deployment
- **Gateway:** Kubernetes Gateway API + Envoy Gateway operator
- **Deployment:** Gateway, HTTPRoute, SecurityPolicy CRDs
- **Learning:** Gateway API, declarative config, dynamic updates

**See [project-plan.md](project-plan.md) for complete roadmap.**

## 🧪 Testing

### Run All Tests

```bash
cd tests
pytest -v
```

### Test Categories

- **Unit Tests:** Service business logic
- **Integration Tests:** End-to-end API flows through gateway

## 🛠️ Technology Stack

- **Container Runtime:** Docker Desktop
- **Orchestration:** Kubernetes (Docker Desktop built-in)
- **Gateway (Phase 2):** Envoy Proxy v1.31
- **Gateway (Phase 3):** Envoy Gateway v1.2 + Gateway API
- **Backend Services:** FastAPI (Python 3.12)
- **Authentication:** Keycloak (OpenID Connect / OAuth 2.0)
- **Authorization:** Custom authz-service with ext_authz
- **Caching:** Redis
- **Testing:** pytest

## 📖 Learning Objectives

This project demonstrates:

1. **Microservices Architecture**
   - Service separation
   - API design
   - Inter-service communication

2. **API Gateway Patterns**
   - Routing and load balancing
   - Authentication (JWT)
   - Authorization (RBAC via ext_authz)
   - Caching strategies

3. **Kubernetes Fundamentals**
   - Deployments, Services, ConfigMaps
   - Persistent storage
   - Service discovery (DNS)
   - LoadBalancer services

4. **Gateway API** (Phase 3)
   - Declarative routing (HTTPRoute)
   - Security policies (JWT, ext_authz)
   - Dynamic configuration
   - Kubernetes-native patterns

5. **Security Best Practices**
   - JWT validation
   - Role-based access control
   - Secret management
   - Fail-closed authorization

## 🔐 Security Notes

**⚠️ This is a development/learning project. DO NOT use in production without:**

- Changing default credentials (Keycloak admin, client secrets)
- Using proper secret management (e.g., Kubernetes Secrets, Vault)
- Enabling TLS/HTTPS
- Implementing network policies
- Adding resource limits and quotas
- Hardening container images
- Implementing proper logging and monitoring

## 🚧 Roadmap

### Phase 3 (Current Focus)
- ✅ Gateway API resource definitions
- ✅ HTTPRoute configurations
- ✅ SecurityPolicy for JWT + ext_authz
- ✅ Deployment scripts (Bash + PowerShell)
- ✅ Documentation
- ⏳ Testing and validation (your review)

### Phase 4 (Future)
- [ ] Rate limiting with RateLimitPolicy
- [ ] Observability (Prometheus, Grafana)
- [ ] Distributed tracing
- [ ] Canary deployments
- [ ] HorizontalPodAutoscaler
- [ ] NetworkPolicies
- [ ] Production hardening

## 🤝 Contributing

This is a learning project. Feel free to:
- Explore the code
- Try different configurations
- Experiment with Gateway API features
- Share learnings and improvements

## 📝 License

This is a personal learning project. Use at your own discretion.

## 📞 Resources

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [Envoy Proxy](https://www.envoyproxy.io/)
- [Keycloak](https://www.keycloak.org/)
- [FastAPI](https://fastapi.tiangolo.com/)

---

**Phase 3 is ready for deployment! 🎉**

See [docs/gateway-api-migration.md](docs/gateway-api-migration.md) for migration guide.

