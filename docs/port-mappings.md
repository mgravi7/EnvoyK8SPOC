# Port Mappings

This document lists Kubernetes service and pod port mappings for the repository, plus applicable Docker Compose host mappings (for local Docker Desktop / docker-compose setups).

| Component | Namespace | K8s Service (file) | Type | Service Port → TargetPort | Pod containerPort(s) (deployment) | Exposed outside cluster? | docker-compose host mapping |
|---|---:|---|---|---:|---:|---:|---:|
| Envoy (API Gateway) | `api-gateway-poc` | `kubernetes/07-envoy-gateway/envoy-service.yaml` | LoadBalancer | 8080 → 8080 (http), 9901 → 9901 (admin) | 8080, 9901 (`kubernetes/07-envoy-gateway/envoy-deployment.yaml`) | Yes — LoadBalancer (Docker Desktop exposes on localhost:8080 and localhost:9901) | `gateway`: `"8080:8080", "9901:9901"` |
| Keycloak (IAM) | `api-gateway-poc` | `kubernetes/04-iam/keycloak-service.yaml` | LoadBalancer | 8180 → 8080 (http), 9000 → 9000 (management) | 8080, 9000 (`kubernetes/04-iam/keycloak-deployment.yaml`) | Yes — LoadBalancer (localhost:8180 and localhost:9000 via Docker Desktop) | `keycloak`: `"8180:8080"` |
| AuthZ service | `api-gateway-poc` | `kubernetes/05-authz/authz-service.yaml` | ClusterIP | 9000 → 9000 | 9000 (`kubernetes/05-authz/authz-deployment.yaml`) | No — internal only | `authz-service`: no ports exposed |
| Customer service | `api-gateway-poc` | `kubernetes/06-services/customer-service.yaml` | ClusterIP | 8000 → 8000 | 8000 (`kubernetes/06-services/customer-deployment.yaml`) | No — internal only | `customer-service`: `"8001:8000"` |
| Product service | `api-gateway-poc` | `kubernetes/06-services/product-service.yaml` | ClusterIP | 8000 → 8000 | 8000 (`kubernetes/06-services/product-deployment.yaml`) | No — internal only | `product-service`: `"8002:8000"` |
| Redis | `api-gateway-poc` | `kubernetes/03-data/redis-service.yaml` | ClusterIP | 6379 → 6379 | 6379 (`kubernetes/03-data/redis-deployment.yaml`) | No — internal only | `redis`: no ports exposed |

Notes:
- No `nodePort` values are configured in Kubernetes manifests; external access is provided by `LoadBalancer` services which Docker Desktop maps to localhost when running locally.
- `docker-compose.yml` host port mappings are included in the rightmost column and apply only to the Docker Compose local setup.
- Readiness/liveness probe ports are the same as the service/pod ports listed above (see each deployment manifest for details).

Generated from repository manifests on branch `feature/k8s-basic`.